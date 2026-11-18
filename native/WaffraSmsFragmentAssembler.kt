package com.waffra.app

import kotlin.math.abs

/**
 * M1038 / #765: structural, owner-local SMS part reassembly.
 * Never group by amount/merchant alone. All inputs already came from the same
 * authenticated Android SMS source, and every original fingerprint is retained.
 * Pure Kotlin, with no finance writer, network, database or phone API.
 */
internal object WaffraSmsFragmentAssembler {
    data class Part(
        val sender: String,
        val identityAt: Long,
        val receivedAt: Long,
        val body: String,
        val sourceIds: List<String>
    )
    data class Group(
        val sender: String,
        val identityAt: Long,
        val receivedAt: Long,
        val body: String,
        val sourceIds: List<String>
    )

    private val purchaseHeading = Regex(
        """(?:شراء\s+عبر\s+نقاط\s+البيع|purchase\s+(?:via|at)\s+(?:pos|point))""",
        RegexOption.IGNORE_CASE
    )
    private val fullDate = Regex(
        """(?:20\d\d[-/.](?:0?[1-9]|1[0-2])[-/.](?:[0-2]?\d|3[01])\s+[0-2]?\d:[0-5]\d|(?:[0-2]?\d|3[01])[-/.](?:0?[1-9]|1[0-2])[-/.]20\d\d\s+[0-2]?\d:[0-5]\d)"""
    )
    private fun hasPurchaseHead(body: String) = purchaseHeading.containsMatchIn(body)
    fun hasCompletePurchase(body: String): Boolean =
        hasPurchaseHead(body) &&
        Regex("""(?:مبلغ|amount)\s*:""", RegexOption.IGNORE_CASE).containsMatchIn(body) &&
        Regex("""(?:لدى|at)\s*:""", RegexOption.IGNORE_CASE).containsMatchIn(body) &&
        fullDate.containsMatchIn(body)

    private fun sameSenderAndClock(a: Group, b: Group): Boolean {
        if (a.sender != b.sender) return false
        if (a.identityAt <= 0 || b.identityAt <= 0) return false
        val timeDistance = abs(a.identityAt - b.identityAt)
        if (timeDistance > 120000L) return false
        if (a.receivedAt <= 0 || b.receivedAt <= 0 ||
            abs(a.receivedAt - b.receivedAt) > 120000L) return false
        return true
    }

    /**
     * A piece must be a *literal substring* or a proven suffix/prefix
     * continuation (>=18 characters). A common purchase header is not
     * sufficient to merge two independently complete bank transactions.
     */
    fun mergeBodies(first: String, second: String): String? {
        val left = first.trim()
        val right = second.trim()
        if (left == right || left.isEmpty() || right.isEmpty() ||
            left.length > 1600 || right.length > 1600) return null
        if (!hasPurchaseHead(left) && !hasPurchaseHead(right)) return null
        if (hasCompletePurchase(left) && hasCompletePurchase(right)) return null
        // Two independently headed messages can share amount/card prefixes.
        // Permit ONLY strict containment; otherwise never join their merchants.
        val bothStartPurchase = hasPurchaseHead(left) && hasPurchaseHead(right)
        if (left.contains(right) && right.length >= 28) return left
        if (right.contains(left) && left.length >= 28) return right
        if (bothStartPurchase) return null

        fun suffixPrefix(a: String, b: String): String? {
            // The truncated bank tail may start *inside* the first part,
            // e.g. "... Marakez Medical Compan ... 18" + "akez Medical ... 18:51".
            for (from in 0..(a.length - 18).coerceAtLeast(0)) {
                val overlap = minOf(a.length - from, b.length)
                if (overlap >= 18 &&
                    a.regionMatches(from, b, 0, overlap) &&
                    overlap >= minOf(28, b.length / 2) &&
                    a.length + b.length - overlap <= 1600)
                    return a + b.substring(overlap)
            }
            return null
        }
        return suffixPrefix(left, right) ?: suffixPrefix(right, left)
    }

    fun combine(parts: List<Part>): List<Group> {
        if (parts.isEmpty()) return emptyList()
        val groups = parts.map {
            Group(it.sender, it.identityAt, it.receivedAt,
                it.body, it.sourceIds.distinct())
        }.toMutableList()
        // Limited to the 1000-row native encrypted SMS candidate window.
        // Only a structurally proven pair can reduce cardinality.
        var changed = true
        while (changed) {
            changed = false
            mergeLoop@ for (i in groups.indices) {
                val a = groups[i]
                for (j in i + 1 until groups.size) {
                    val b = groups[j]
                    if (!sameSenderAndClock(a, b)) continue
                    val joined = mergeBodies(a.body, b.body) ?: continue
                    groups[i] = Group(a.sender,
                        minOf(a.identityAt, b.identityAt),
                        minOf(a.receivedAt, b.receivedAt),
                        joined, (a.sourceIds + b.sourceIds).distinct())
                    groups.removeAt(j)
                    changed = true
                    break@mergeLoop
                }
            }
        }
        return groups
    }
}
