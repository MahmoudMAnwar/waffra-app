#!/usr/bin/env python3
"""M228 24-route exact SHA staging review, NEVER a production activation."""
from __future__ import annotations
import json
import os
from pathlib import Path
import re
import subprocess

BASE = "8a460fa3d537ee7e8343b01e49d794140e66652a"
CHANGED = set([".github/workflows/m147-final-main-review-gate.yml","docs/qa/m228-24-route-source-preflight.md","lib/storage/waffra_finance_24_route_preflight.dart","lib/storage/waffra_production_finance_authority_binding.dart","scripts/qa/m228_route_readiness_scope_review.py","test/storage/m228_24_route_preflight_test.dart"])
def git(*args: str) -> str:
    return subprocess.check_output(["git",*args],text=True).strip()
def require(ok: bool, msg: str) -> None:
    if not ok: raise SystemExit("M228 24-route review BLOCKED: "+msg)

def main() -> None:
    head=git("rev-parse","HEAD")
    require(os.getenv("REVIEW_HEAD_SHA","")==head,"untrusted/missing SHA")
    base=git("rev-parse","refs/remotes/origin/main")
    require(base==BASE,"main advanced; start a fresh route staging branch")
    changed=set(filter(None,git("diff","--name-only",BASE,head).splitlines()))
    require(changed==CHANGED,"unreviewed paths: "+repr(sorted(changed ^ CHANGED)))
    routing=Path("lib/storage/waffra_production_finance_routing_gate.dart").read_text()
    catalog=re.search(r"enum WaffraFinanceRoute\s*\{([^}]*)\}",routing)
    require(catalog is not None,"route enum missing")
    routes=[line.strip().rstrip(",") for line in catalog.group(1).splitlines()
            if line.strip() and not line.strip().startswith("//")]
    require(len(routes)==len(set(routes))==24,"24 unique finance routes required")
    checker=Path("lib/storage/waffra_finance_24_route_preflight.dart").read_text()
    binder=Path("lib/storage/waffra_production_finance_authority_binding.dart").read_text()
    tests=Path("test/storage/m228_24_route_preflight_test.dart").read_text()
    guard=Path("lib/storage/waffra_production_finance_source_guard.dart").read_text()
    release=Path("lib/storage/waffra_production_cutover_release_gate.dart").read_text()
    for required in [
      "WaffraFinanceRoute.values",
      "selector.requireRoute(route)",
      "WaffraRouteSourceOutcome.guardedLegacy",
      "WaffraRouteSourceOutcome.blocked",
      "productionCutoverAuthorized => false",
      "Map<WaffraFinanceRoute, WaffraRouteSourceOutcome>.unmodifiable",
    ]: require(required in checker,"missing negative source preflight "+required)
    for required in [
      "final routePreflight = const WaffraFinance24RoutePreflight().inspect(",
      "if (!routePreflight.allContractsAcceptEncrypted)",
      "checkpoint.sourceDigest != evidence.storage.sourceDigest",
      "await authority.load(route: startupRoute)",
    ]: require(required in binder,"missing binding guard "+required)
    require(binder.index("checkpoint.sourceDigest != evidence.storage.sourceDigest") <
            binder.index("final routePreflight ="),"route check before OS-backed key and source digest")
    for required in [
      "for (final missing in WaffraFinanceRoute.values)",
      "missing ${missing.name} blocks the entire encrypted source",
      "missing external witness or SQL witness",
      "reports are immutable",
    ]: require(required in tests,"missing test: "+required)
    require("all_live_writers_not_yet_routed" in guard,"legacy source gate altered")
    require("bool get automaticallyActivateSqlCipher => false;" in release,
            "automatic production activation may not be allowed")
    require("certifiedEvidence: " not in Path("lib/main.dart").read_text(),
            "Home unexpectedly supplies unverified production evidence")
    output={
      "milestone":"M228",
      "reviewed_sha":head,
      "base_main_sha":BASE,
      "route_count":len(routes),
      "structural_route_contract_probe_added":True,
      "real_android_live_route_certification":False,
      "all_24_routes_production_certified":False,
      "two_real_android_devices_verified":False,
      "production_cutover_authorized":False,
      "changed_paths":sorted(changed),
    }
    dest=Path("build/m147-final-review-report.json")
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(json.dumps(output,indent=2,ensure_ascii=False)+"\n")
    print(json.dumps(output,indent=2))
if __name__=="__main__":main()
