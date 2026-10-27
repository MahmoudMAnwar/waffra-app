import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_smart_features.dart';

/// Synthetic performance data. CI timings describe the runner, not a phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final samples = <Map<String, Object>>[];

  List<String> messages(int count) => List.generate(count, (i) =>
      'شراء PoS\nبـ${i + 1}.25SR\nمن 1111\n16/10/26 00:43');

  void measure(String name, void Function() action) {
    for (var i = 0; i < 4; i++) {
      action();
    }
    final durations = <int>[];
    for (var i = 0; i < 21; i++) {
      final watch = Stopwatch()..start();
      action();
      watch.stop();
      durations.add(watch.elapsedMicroseconds);
    }
    durations.sort();
    final result = <String, Object>{
      'name': name,
      'samples': durations.length,
      'p50_us': durations[durations.length ~/ 2],
      'p95_us': durations[(durations.length * 95 ~/ 100).clamp(0, durations.length - 1)],
      'min_us': durations.first,
      'max_us': durations.last,
    };
    samples.add(result);
    // Measurements are informational, never a CI-host-dependent red gate.
    // ignore: avoid_print
    print('M276-MEASUREMENT: ${jsonEncode(result)}');
  }

  for (final count in [1, 20, 100]) {
    test('M276 bank SMS split, parse, hash $count messages', () {
      final pasted = messages(count).join('\n');
      final parsed = splitBankMessages(pasted);
      expect(parsed.length, count);
      expect(BankParser.parse(parsed.last).amount, count + .25);
      expect({for (final item in parsed) bankSmsHash(item)}.length, count);

      measure('sms_split_parse_hash_$count', () {
        final segments = splitBankMessages(pasted);
        var recognized = 0;
        final fingerprints = <String>{};
        for (final item in segments) {
          if (BankParser.parse(item).amount != null) recognized++;
          fingerprints.add(bankSmsHash(item));
        }
        if (recognized != count || fingerprints.length != count) {
          throw StateError('Parsing or deduplication lost input');
        }
      });
    });

    test('M276 pre-save import preview $count messages', () {
      final pasted = messages(count).join('\n');
      final expected = waffraSummarizeBankPaste(pasted, <String>{});
      expect(expected.fresh, count);
      expect(expected.duplicates, 0);
      measure('sms_preview_$count', () {
        final result = waffraSummarizeBankPaste(pasted, <String>{});
        if (result.fresh != count || result.duplicates != 0) {
          throw StateError('Unexpected preview result');
        }
      });
    });
  }

  test('M276 serialize and deserialize 1000 finance entries', () {
    final entries = List.generate(1000, (i) => MoneyEntry(
      id: 'performance-$i',
      title: 'عملية تجريبية $i',
      category: i.isEven ? 'مطاعم' : 'فواتير',
      amount: i + .25,
      income: i.isEven,
      date: DateTime(2026, 10, 27, 10, 30),
      notes: 'Synthetic test data only',
    ));
    measure('ledger_1000_json_round_trip', () {
      final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
      final decoded = (jsonDecode(encoded) as List).map((v) =>
          MoneyEntry.fromJson(Map<String, dynamic>.from(v as Map))).toList();
      if (decoded.length != entries.length ||
          decoded.last.amount != entries.last.amount ||
          decoded.first.notes != entries.first.notes) {
        throw StateError('Round-trip ledger integrity error');
      }
    });
  });

  test('M276 group 2000 finance entries by category', () {
    final entries = List.generate(2000, (i) => WaffraSmartEntry(
      id: 'aggregation-$i',
      title: 'عملية $i',
      category: i.isEven ? 'مواصلات' : 'مطاعم',
      amount: i.isEven ? 2.25 : 3.75,
      income: false,
      date: DateTime(2026, 10, 27),
    ));
    measure('category_2000_aggregation', () {
      final grouped = waffraCategoryOutflows(entries);
      final sum = grouped.values.fold<double>(0, (a, b) => a + b);
      if (sum != 6000 || grouped.length != 2) {
        throw StateError('Category balance mismatch');
      }
    });
  });

  tearDownAll(() {
    final output = File('build/performance/m276_finance_microbench.json');
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'milestone': 'M276',
        'head_sha': Platform.environment['WAFFRA_EXPECTED_HEAD_SHA'] ?? 'local',
        'environment': 'flutter_test_host_not_physical_android',
        'decision': 'informational_only_no_fixed_latency_gate',
        'warmups_per_scenario': 4,
        'samples_per_scenario': 21,
        'scenarios': samples,
      }) + '\n',
    );
    expect(samples.length, 8);
  });
}
