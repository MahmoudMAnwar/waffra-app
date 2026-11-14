"""M927: legacy AI/cloud SMS must not be imported by active Dart runtime."""
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[2]
LIB=ROOT/'lib'
REL=re.compile(r"(?m)^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]")
RETIRE={
    'waffra_ai_finance_brain.dart',
    'waffra_ai_finance_coach.dart',
    'waffra_ai_recorded_answers.dart',
    'waffra_ask_scope.dart',
    'waffra_cloudflare_sms_gateway.dart',
    'waffra_sms_cloud_service.dart',
    'waffra_sms_cloud_redactor.dart',
}
ROOTS=(
    LIB/'main.dart',
    LIB/'waffra_auto_sms.dart',
    LIB/'waffra_auto_sms_consent.dart',
    LIB/'waffra_auto_sms_autopost.part.dart',
)

def runtime_graph():
    pending=list(ROOTS)
    visited=set()
    edges={}
    while pending:
        current=pending.pop()
        current=current.resolve()
        if current in visited:
            continue
        if not current.is_file():
            raise AssertionError('Missing genuine Dart runtime import: '+str(current))
        if not current.is_relative_to(LIB.resolve()):
            continue
        visited.add(current)
        source=current.read_text(encoding='utf-8')
        children=[]
        for match in REL.finditer(source):
            uri=match.group(1)
            if uri.startswith('package:waffra/'):
                child=LIB/uri.removeprefix('package:waffra/')
            elif ':' not in uri:
                child=current.parent/uri
            else:
                continue
            if child.suffix!='.dart':
                continue
            if not child.is_file():
                raise AssertionError('Broken real Dart dependency: '+str(current)+' -> '+str(child))
            children.append(child.resolve())
            pending.append(child)
        edges[current]=children
    return visited,edges

class M927RetiredCloudAiRuntimeGraph(unittest.TestCase):
    def test_active_home_and_native_sms_import_graph_never_reaches_retired_model(self):
        nodes,edges=runtime_graph()
        self.assertGreater(len(nodes),35,msg='Must traverse real product dependency graph, not mock')
        self.assertIn((LIB/'waffra_bank_sms_facts.dart').resolve(),nodes)
        self.assertIn((LIB/'waffra_sms_intelligence.dart').resolve(),nodes)
        self.assertIn((LIB/'waffra_auto_sms_consent.dart').resolve(),nodes)
        for name in RETIRE:
            self.assertNotIn((LIB/name).resolve(),nodes,
                             msg='Retired external AI/cloud SMS reachable from active entrypoints: '+name)
        main=(LIB/'main.dart').read_text(encoding='utf-8')
        self.assertIn("part 'waffra_home_sms_confirmation.part.dart';",main)
        self.assertIn("part 'waffra_auto_sms_autopost.part.dart';",main)
        self.assertIn("WaffraSmsIntelligence.classify(",main)
        self.assertGreater(len(edges),35)

    def test_retired_cloud_analyzer_stays_fail_closed_without_erasing_local_sms(self):
        consent=(LIB/'waffra_auto_sms_consent.dart').read_text(encoding='utf-8')
        service=(LIB/'waffra_sms_cloud_service.dart').read_text(encoding='utf-8')
        gateway=(LIB/'waffra_cloudflare_sms_gateway.dart').read_text(encoding='utf-8')
        self.assertIn("await prefs.remove('waffra_cloud_sms_installation_consent_v2');",consent)
        self.assertIn('await WaffraAutoSms.optIn();',consent)
        self.assertIn('static Future<bool> hasConsent()async=>false;',service)
        self.assertIn('static Future<Map<String,Object?>?> analyzeIfConsented(String source)async=>null;',service)
        self.assertIn("static const String configuredUrl = '';",gateway)
        self.assertIn('static bool get configured => false;',gateway)
        self.assertIn('}) async => null;',gateway)
        self.assertNotIn('WaffraSmsCloudService.',consent)
        self.assertNotIn('WaffraCloudflareSmsGateway.',consent)

if __name__=="__main__":
    unittest.main()
