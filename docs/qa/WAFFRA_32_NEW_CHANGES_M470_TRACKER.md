# وفرة — سجل التعديلات الـ32 / M470

**الفرع:** `feat/m470-approved-32-fixes-20261106` · **الأساس:** `main@1e194366e1985914c381a0d3424edc28542e6def` · **الحالة:** تنفيذ مرحلي؛ **لا تعني إضافة كود نجاح CI أو اختبار هاتف**.

## تعريف الحالة
- **Done** = نُفذ المطلوب كاملًا، داخل الـPR نفسه، واجتاز اختبارات نفس SHA وجرى التحقق من سلوكه.
- **كود + اختبار / CI قيد التحقق** = موجود على الفرع لكن ليس Done.
- **جزئي** = جزء فقط نُفذ؛ الجزء الآخر مفتوح.
- **لم يُنفذ** = لا يوجد تنفيذ معتمد للطلب في هذا PR.
- **غير مُتحقَّق منه** = الوصف الدقيق للبند السابق غير متاح في السياق المسترجع؛ لا نفترض محتواه أو نختلق اكتماله.

| رقم | التعديل | الحالة الدقيقة | أثر الكود |
|---:|---|---|---|
| 1 | إصلاح تسجيل الخروج في التطبيق كله؛ مراجعة جميع أماكن تسجيل الخروج التي لا تعمل؛ مختلف عن رفض كلمة المرور المولدة | كود مسار مركزي لمنع الضغط المكرر وتقديم خطأ واضح عند فشل تعليق SMS أو إنهاء الجلسة؛ لا يمس بيانات الأموال؛ اختبار رجوع مضاف؛ CI/Android قيد الفحص | lib/main.dart + test/m470_logout_and_refresh_test.dart |
| 2 | إصلاح Pull to Refresh في شاشات التطبيق خصوصًا البطء الشديد وإعادة التحميل | كود تجنب فك JSON وإعادة بناء الواجهات إذا لم يتغير SHA/digest وجيل SQLCipher بعد قراءة آمنة؛ guarded legacy يظل كاملًا؛ اختبار رجوع مضاف؛ CI/Android قيد الفحص | lib/main.dart + test/m470_logout_and_refresh_test.dart |
| 3 | وصف البند الأصلي غير مسترجَع بدقة من سياق المحادثة المتاح | غير مُتحقَّق منه — لا يُعلن Done |  |
| 4 | وصف البند الأصلي غير مسترجَع بدقة من سياق المحادثة المتاح | غير مُتحقَّق منه — لا يُعلن Done |  |
| 5 | زر «الحساب» بجانب تاريخ إضافة الدخل/المصروف مع اختيار الحساب أو «إضافة حساب» | كود زر «الحساب» بمحاذاة التاريخ واختيار الحساب من قائمة الجهات موجود؛ الاختبارات والـAndroid لم يعتمدا | lib/main.dart + test/m470_sms_sender_and_rule_accuracy_test.dart |
| 6 | عند عدم وجود حسابات، زر «إضافة حساب» بجانب التاريخ ينشئ الحساب ويعود لنفس المعاملة | كود زر «إضافة حساب» عند عدم وجود حسابات والعودة لنفس نموذج العملية مع حفظ Controllers وارتباط الحساب الجديد موجود؛ يحتاج CI وتجربة Android | lib/main.dart + test/m470_sms_sender_and_rule_accuracy_test.dart |
| 7 | بعد استبعاد جميع رسائل مرسل، سؤال مستقل عن استبعاد المرسل نفسه | كود سؤال مستقل بعد الاستبعاد الجماعي الناجح لكل مرسل اكتملت رسائله؛ لا يتم حظر المرسل دون موافقة جديدة | lib/main.dart + test/m470_sms_excluded_senders_test.dart |
| 8 | إعادة تسمية قائمة المرسلين المحظورين إلى «المستبعدون» مع إلغاء الاستبعاد | كود قسم «المستبعدون» ضمن إعدادات الرسائل، عرض الأسماء واستعادة استقبال رسائل المرسل القادم؛ يحتاج CI/Android | lib/main.dart + lib/waffra_auto_sms.dart + native/WaffraMainActivity.kt |
| 9 | عدم تحليل أو عرض رسائل جديدة من مرسل مستبعد حتى إلغاء استبعاده | كود قائمة استبعاد مشفرة بنطاق حساب موثوق في Android، منع القادم قبل تحليل الرسالة وإدخالها؛ تحذير فشل قراءة مشفر؛ CI/Android معلق | native/WaffraAutoSmsStore.kt + lib/waffra_auto_sms.dart |
| 10 | تسريع تحديد واستبعاد مئات رسائل المراجعة، مثل 500 رسالة | تحسين كود اختيار 500 رسالة بـ Set وListView.builder ومعالجة 100 لكل دفعة وكاش مشفر؛ قياس الأداء الفعلي معلق | lib/main.dart + native/WaffraAutoSmsStore.kt + test/m470_sms_excluded_senders_test.dart |
| 11 | اعتماد أول SMS من مرسل جديد ينشئ حسابه بعد تأكيد الاسم والرصيد الافتتاحي الافتراضي صفر، ثم يقيد العملية عليه | غير منفذ كمسار متكامل — يتطلب موافقة المستخدم وحفظًا ماليًا ذريًا | — |
| 12 | إصلاح تداخل العدد وكلمة «رسائل» في قائمة المرسلين وصياغة «3 رسائل بانتظار المراجعة» | كود إصلاح مضاف إلى Home مع Directionality وعزل عدد الرسائل؛ اختبار رجوع مضاف؛ CI/Android معلق | lib/main.dart + test/m470_sms_sender_and_rule_accuracy_test.dart |
| 13 | وصف البند الأصلي غير مسترجَع بدقة من سياق المحادثة المتاح | غير مُتحقَّق منه — لا يُعلن Done |  |
| 14 | وصف البند الأصلي غير مسترجَع بدقة من سياق المحادثة المتاح | غير مُتحقَّق منه — لا يُعلن Done |  |
| 15 | وصف البند الأصلي غير مسترجَع بدقة من سياق المحادثة المتاح | غير مُتحقَّق منه — لا يُعلن Done |  |
| 16 | عدم اقتراح قاعدة لا تطابق رسالة التحويل الأصلية؛ الكلمات والمعاينة يجب أن تتفق مع المرسل والنوع | كود إصلاح مضاف إلى شاشة القواعد لمنع fallback عام والتحقق من النوع/المرسل/النص؛ اختبار رجوع مضاف؛ CI/Android معلق | lib/waffra_sms_rule_settings_page.dart + test/m470_sms_sender_and_rule_accuracy_test.dart |
| 17 | وصف البند الأصلي غير مسترجَع بدقة من سياق المحادثة المتاح | غير مُتحقَّق منه — لا يُعلن Done |  |
| 18 | وصف البند الأصلي غير مسترجَع بدقة من سياق المحادثة المتاح | غير مُتحقَّق منه — لا يُعلن Done |  |
| 19 | وصف البند الأصلي غير مسترجَع بدقة من سياق المحادثة المتاح | غير مُتحقَّق منه — لا يُعلن Done |  |
| 20 | وصف البند الأصلي غير مسترجَع بدقة من سياق المحادثة المتاح | غير مُتحقَّق منه — لا يُعلن Done |  |
| 21 | وصف البند الأصلي غير مسترجَع بدقة من سياق المحادثة المتاح | غير مُتحقَّق منه — لا يُعلن Done |  |
| 22 | الجلسة لمدة 60 ثانية ثم قفل بصمة يغطي الشاشة مع استعادة آخر نافذة/دروب داون | إضافة كود مؤقت قفل بعد 60 ثانية بالبصمة فوق الـNavigator مع الحفاظ على نموذج الحوار المفتوح، واختبارات Widget؛ CI/Android قيد الفحص | lib/waffra_idle_biometric_overlay.dart + lib/main.dart + test/m470_idle_biometric_overlay_test.dart |
| 23 | أنواع الحسابات المالية وربط الرسائل بحسب الجهة والحساب وآخر أربعة أرقام | جزئي: أنواع بنكية فرعية ثابتة وProvider ID موثق داخل جدول SQLCipher مستقل + V3 optional metadata + مراجعة SMS + اختبار استعادة حساب مؤرشف؛ الأنواع المفتوحة بالكامل وتجربة الهاتف لم تُعتمد | lib/storage/waffra_account_details_schema.dart + lib/storage/waffra_account_details_backup.dart + test/storage/m470_account_details_v3_test.dart |
| 24 | اختيار تاريخ التحويل بين الحسابات | كود اختيار تاريخ التحويل واختبار موجودان؛ نتائج نفس SHA وتجربة Android قيد التحقق | lib/main.dart + test/m470_account_scope_and_transfer_date_test.dart |
| 25 | إظهار البنك/الجهة ثم الحساب التابع في نماذج المعاملات | كود البنك/الجهة ثم الحساب التابع في Home اليدوي والتحويل ومراجعة SMS والمتكررة موجود؛ CI والهاتف لم يُعتمدا | lib/main.dart + lib/waffra_recurring_account_groups.dart + test/m470_recurring_provider_accounts_test.dart |
| 26 | وضع قائمة «كل الحسابات» داخل بطاقة الرصيد الخضراء | كود قائمة كل الحسابات داخل بطاقة الرصيد الخضراء واختبار Widget موجودان؛ التحقق النهائي معلق | lib/main.dart + test/m470_balance_header_account_picker_test.dart |
| 27 | إعادة تصميم نافذة إضافة حساب مالي وفصل النوع والرصيد الافتتاحي | كود نافذة الحساب الجديدة والنوع التفصيلي والبنك والرصيد الافتتاحي واختبار موجود؛ CI والهاتف معلقان | lib/waffra_new_account_dialog.dart + lib/waffra_accounts_manager_page.dart + test/m470_new_account_dialog_test.dart |
| 28 | إزالة فلتر «عمليات بدون حساب» ومنع إنشاء عمليات جديدة بلا حساب | كود إزالة بدون حساب وإلزام ربط الحساب للمعاملات المالية الجديدة بكل المسارات المعروفـة؛ اختبار قبول الهاتف قيد التحقق | lib/main.dart + test/m470_account_scope_and_transfer_date_test.dart |
| 29 | عرض ميزانية شهرية للحساب المختار ومجموع ميزانيات الحسابات في «كل الحسابات» | كود ربط الميزانية المسماة بحساب + حفظ JSON مشفر + بطاقة ميزانيات لكل حساب، ومجموع كل الحسابات بلا عد مكرر؛ ترحيل V3 والتجربة الفعلية قيد التحقق | lib/main.dart + lib/waffra_account_monthly_budget_policy.dart + test/m470_account_monthly_budget_policy_test.dart |
| 30 | اشتراط تحديد البنك والحساب عند إنشاء/تعديل العملية المتكررة | كود اختيار جهة وحساب إلزاميًا في إنشاء/تعديل المتكررة والحفظ الذري لافتراضي حساب SQLCipher موجود؛ CI والهاتف قيد التحقق | lib/main.dart + lib/storage/waffra_fresh_finance_modules_repository.dart + test/m470_recurring_provider_accounts_test.dart |
| 31 | اشتراط تحديد حساب الدفع عند تأكيد استحقاق عملية متكررة | كود اختيار حساب الدفع عند الاستحقاق واختبار SQLCipher موجود؛ قبول جهاز Android معلق | lib/main.dart + test/storage/m470_recurring_payment_sqlcipher_integration_test.dart |
| 32 | إصلاح خطأ الحفظ عند الضغط على «تم الدفع» للمتكررة | جزئي: كود حفظ دفع المتكررة ذريًا ومنع التكرار وتسجيل sourceType='recurring' واختبارات SQLCipher؛ إثبات نجاح الزر على هاتف Android غير متاح | lib/main.dart + lib/storage/waffra_home_transaction_capture.dart + test/storage/m470_verified_recurring_payment_capture_test.dart |

## نطاق التنفيذ الذي دخل فرع M470
1. فلتر الرئيسية يعرض «كل الحسابات» والحسابات الفعلية فقط؛ اختيار `none` المحفوظ سابقًا يعود آمنًا إلى «كل الحسابات» دون حذف أي تاريخ قديم؛ لا يوجد ادعاء بترحيل آلي لسجلات SMS غير المربوطة.
2. نموذج تحويل حساب إلى حساب يتضمن اختيار التاريخ دون تغيير معرّف الطلب الثابت ودون تحويل المبلغ إلى دخل/مصروف.
3. عند تأكيد دفع استحقاق متكرر أو حصة نقدية من استحقاق هدف، يطلب حساب مالي موثق؛ الحساب الافتراضي الحالي يُقترح إذا كان موثقًا، ولا يؤخذ حساب الهيدر تلقائيًا.
4. مسار حفظ «تم الدفع» على SQLCipher يُضيّق التغيير المصرح به إلى السجل الجديد والتأجيل المرتبط به، مع رفض أي تغيير مالي غير متعلق؛ تم إنشاء اختبارات للحماية والتكرار والتخزين المشفّر.

## ملاحظات ضرورية قبل Done
- الـ32 تعديل **هدف إجمالي**، لا يعني دخولهم الـPR أو نجاحهم. البنود 1–21 غير مسترجعة من نصها الأصلي هنا حتى لا ننسب للعميل نصًا غير مسترجَع؛ تُستكمل المطابقة مع القائمة الأصلية قبل إعلان النتائج.
- يجب تشغيل M385 change-scope guard وجميع اختبارات Flutter وPython/Android على SHA الفعلي للـPR. 
- اختبار جهاز Android موقع مطلوب قبل تقرير جاهزية إصدار APK جديد من `main`.
- لا تدمج التعديلات لهذا الدفتر فقط؛ أحضر نتائج CI واختبارات الإصدار. 

## تذاكر القبول المهمة للمتبقي
- #25: هيكل البنك/الجهة والحسابات التابعة يحتاج إثبات وجود تعريف جهات حقيقي قبل إعداد dropdown متسلسل.
- #29: الميزانيات في التطبيق مستقلة ويمكن أن تتوزع بين عدة حسابات؛ لا تقسم سقف الميزانية افتراضًا أو تضاعف الإجمالي. ميزانية الحساب المختار تُعرض وفق ارتباطات مالية موثقة، ومجموع «كل الحسابات» دون عدّ مكرر.
- #30: تم تنفيذ قائمتين متتاليتين في *إعدادات الافتراضي للمتكررة* فقط، مع إلزام حساب فعلي؛ الجهات المعروفة تُجمع من مسمى الحساب للعرض ولا يُخمن مصدر الخصم، والبنوك غير المعروفة تبقى منفصلة. إنشاء/تعديل المتكررة نفسه لم يُربط بعد. لا تصبح المتكررة صالحة للحفظ إلا بحساب قائم. ربط الافتراضي الجديد يجب أن يكون متسقًا مع إنشاء السجل المالي، دون ترك جزء محفوظ عند فشل الآخر.
- #31/#32: اختبار قبول: دفع ناجح مرة واحدة، منع دفع مكرر، إلغاء دون خصم، رفض حساب محذوف/مؤرشف، والرجوع من شاشة المراجعة بلا فقد البيانات.

### مراجعة إضافات شاشة ربط المتكررة الموجودة
- `lib/waffra_recurring_account_groups.dart` يجمع الحسابات الفعلية غير المؤرشفة باسم البنك المعروف فقط؛ المؤسسات غير المعروفة تظل منفصلة ولا يُخمن مصدر مالي.
- `lib/waffra_account_context_settings.dart` يعرض Drop-down أول للجهة/البنك ثم الثاني للحساب المرتبط؛ اختيار الجهة لا يختار الحساب تلقائيًا، ولا يوجد خيار «بدون حساب» عند التعديل.
- لا تعتبر هذه الشاشة تحقيقًا للبند #30 عند إنشاء عملية متكررة من الصفر؛ يلزم مسار متكامل آمن يربط الحساب منذ الإنشاء.

## تقدم تنفيذ M470 في PR #395 (بعد commits الإعدادات)
- `lib/waffra_recurring_account_groups.dart`: تجميع حسابات البنوك السعودية المعروفة للعرض فقط، وعدم دمج البنوك غير المعروفة افتراضًا.
- `WaffraAccountContextSettings._editRecurring`: Dropdown للجهة/البنك ثم للحساب الفعلي؛ تعطيل حفظ الافتراضي حتى اختياره، مع إعادة التحقق من SQLCipher witness.
- اختبار `test/m470_recurring_provider_accounts_test.dart` للتحقق من تعدد الحسابات تحت البنك نفسه واستبعاد المؤرشف وعدم اختيار حساب ضمنيًا.
- **لا يعتبر #30 كاملًا**: إنشاء المتكررة يحتاج ربطًا ذريًا بين السجل والحساب الافتراضي؛ CI وAndroid لم يتأكدا كاملًا.

- تحديث M470 الإضافي: عند تسجيل دفع متكررة أصبح `MoneyEntry` يحتفظ بـ `sourceType: 'recurring'` بدل القيمة الافتراضية `manual`، مع اختبار يؤكد مصدر العملية؛ هذا لا يثبت بعد نجاح الدفع الفعلي على الهاتف.

## M470 budget projection notes
- Added a pure integer-halalas projection for explicitly assigned monthly per-account budget caps, their linked expenses, and All accounts sum. It prevents duplicate `(budgetId,accountId)` allocations and excludes expenses without a saved allocation. This does NOT create or restore allocations, does not remap existing standalone budgets, and does not yet update the actual Home budget card.
- The user-approved rule is to show the chosen account's own monthly caps, and All accounts' combined caps. No guessed split of one shared monthly budget across multiple accounts is permitted.

- M470 #27: نافذة إنشاء الحساب صارت تعرض نوع الحساب والرصيد الافتتاحي في حقلين منفصلين، وتظهر قائمة الجهة/البنك لو اختار بنكي؛ البيانات تصل لنفس API الحفظ المشفّر، ولا تُحتسب أرصدة البداية دخلًا. أسماء البنوك تُحفظ ضمن مسمى الحساب فقط، دون إدعاء ربط بنكي إلكتروني أو إضافة نوع في قاعدة البيانات. الاختبارات الجديدة لم تُعتبر معتمدة قبل CI.

- M470 #25: نموذج معاملات الحسابات الموثق يعرض الجهة/البنك أولًا ثم الحساب الحقيقي التابع لها، سواء كمصدر للدخل/المصروف أو كمصدر/وجهة للتحويل الداخلي؛ اختيار جهة جديدة يمسح الحساب السابق بدل تمريره تلقائيًا. لم يتغير SQLCipher writer أو اختيار حساب هيدر الرئيسية. اختبارات مصدرية مضافة؛ ربط محرر الدخل/المصروف الأصلي في Home ما زال مطلوبًا.

- M470 #26: نقل زر فتح قائمة الحسابات إلى داخل بطاقة الرصيد الخضراء نفسها بدل صف منفصل. لا تتغير أرصدة الحسابات ولا يورث الاختيار إلى حفظ المعاملات؛ اختبار Widget يضغط الزر ويؤكد استدعاء فتح القائمة.


## M470 follow-up on the six partially implemented items (2026-11-06)
- #25 **CODE WIRED, CI/PHONE PENDING:** Home entrySheet now has bank/provider -> active linked money account for newly posted manual income, expenses and transfers, in addition to previously linked verified account-manager editor. Changing bank clears the account, and Home displayed account is never a writer input.
- #28 **CODE WIRED, CI/PHONE PENDING:** reviewSmsAccountLinks now demands one verified active account for every new money posting, including SMS, receipts, manual, recurring and goal-due. An absent account blocks the save. No historical unassigned record is deleted/guessed; old history is still accessible.
- #30 **CODE WIRED, CI/PHONE PENDING:** actual recurring creation/edit now selects provider then account. Its schedule JSON includes optional accountId and typed recurring SQL projection writes the default account row in the same locked transaction. An invalid account aborts both schedule and linkage; backed up snapshot includes the accountId. Legacy schedules without it remain valid history, but new edits cannot save without selection.
- #32 **PARTIAL PENDING REAL DEVICE:** earlier verified atomic Paid/duplicate prevention plus provenance remain in code; no proof yet on signed Android that the original Paid failure is resolved end-to-end.
- #23 **PARTIAL:** 4 baseline account types plus trusted masked-SMS linkage exist. Structured user-defined advanced financial account types, versioned secure storage and backup migration remain unimplemented; do not confuse bank prefix in a label with structured provider identity.
- #29 **PARTIAL:** integer-halalas pure calculation is present. No confirmed persistent per-account cap assignment through UI/SQLCipher + V3 restore or live header monthly-budget card view yet. No synthetic splitting of a standalone shared budget.
- Existing M440 transfer regression was a test-viewport missed tap; the test now scrolls to the visible submit button before asserting invalid amount rejection.
- These are scoped code changes in PR #395, not final Done items until exact HEAD CI checks and signed Android acceptance succeed.

## M470 later verified-code follow-up (latest, before exact-head CI)
- #25: Original Home income/expense/transfer and SMS review now have sequential provider -> linked account pickers. Provider change resets prior account; SMS trust also requires bank-sender agreement. This is CODE CANDIDATE, not signed-device Done.
- #28: Explicit verified active account is mandatory for NEW money, no option to save new bank SMS, manual, OCR, recurring or cash goal due unassigned. Historic rows remain readable. CODE CANDIDATE, not phone Done.
- #29: A named monthly budget may be explicitly assigned to an active account from the create/edit dialog. assignedAccountId persists with budget JSON, leaves prior unassigned/shared budgets intact, and the Home selected-account budget card now uses matched budgets and verified scoped expenses. The All view includes each budget only once. CODE CANDIDATE pending exact-head CI, V3 restore and phone acceptance; standalone-budget SQL allocations continue to require their own source verification.
- #30: Actual recurring create/edit requires bank and account; accountId survives schedule serialization and the typed schedule and default link are one SQLCipher transaction. CODE CANDIDATE pending exact-head CI and phone testing.
- #23: Structured user-defined financial account subtypes/identity remain PARTIAL, with legacy 4 account kinds, safe bank grouping, explicit suffix registration and existing sender-scoped learning; no authenticated schema extension or full multi-device V3 roundtrip proof for new subtypes yet.
- #32: PARTIAL, source-atomic Paid implementation and one-post checks exist; signed Android Paid/duplicate/retry acceptance is not yet verified.
- No full completion claims for the six partial items or all 32 are authorized yet.

## مراجعة الوضع بعد إصلاح CI وإضافة #22 و#23 (2026-11-06)
- عدد البنود المثبت وصفها الأصلي = 11 (#22–#32). عدد البنود غير المسترجعة = 21 (#1–#21). لا يعني الغياب أنها نُفذت أو أنها ناقصة؛ لا تقدير مختلق لحالتها.
- #22 قفل 60 ثانية أمام كل الشاشات من داخل MaterialApp.builder القائم (لا builder مكرر)، مع الاحتفاظ بالمسارات والنماذج وفتح بصمة إلزامية.
- #23 حُفظ نوع فرعي ثابت والبنك/الجهة المختارة بشكل مستقل ومشفر مع حساب واحد، دون المساس بالأصناف الأربعة الأصلية أو بالرصيد؛ أضيفت صيغة اختيارية V3 تدعم الحسابات المؤرشفة وتمنع provider مزور. الأنواع التعريفية القابلة للإضافة بحرية بواسطة المستخدم غير متاحة بعد؛ متطلبات الهاتف لم تعتمد.
- فشل 4 اختبارات CI سابقًا بسبب توقعات نصية قديمة في M343/M359/M401/M402، وقد تم تعديل assertions لمراعاة حساب الميزانيات بحسب الحساب المحدد والقوائم المنسدلة بخطوتين دون تخفيف القاعدة الوظيفية.
- لا تنقل أي بند إلى Done إلا بعد نجاح كامل فحوص CI على آخر commit، والتحقق من سلوك الجهاز؛ فشل واحد أو عدم تحقق معناه مرشح فقط.


## البنود الأصلية المسترجعة من نص المستخدم — 2026-11-06
- البنود 5–12 و16 أعلاه مصدرها نص المستخدم مباشرة؛ لا يجوز تغيير ترقيمها.
- المعلومات عن البنود 13–15 تحدد موضوعات تحويل الرسائل والرجوع من «علّم وفرة»، لكن الوصف الفردي الدقيق لم يسترجع. البنود 1–4 و17–21 لا يزال وصفها الأصلي غير متاح.
- #12 و#16 تغييران حقيقيان في الكود على هذا الفرع مع اختبار regression. وجود commit ليس نجاح CI أو UAT.
- أولوية الباقي: #5/#6 واجهة حساب تحفظ النموذج، ثم #7–#9 حظر المرسل مع التخزين والتراجع الآمن، #10 اختبار أداء 500 رسالة، #11 معاملة إنشاء الحساب + الإدخال المالي الذرية.

- متابعة #5/#6: أضيف إجراء الحساب بجوار التاريخ مع إخفاء محددات الجهة الفارغة، وفتح إدارة الحسابات فوق مسودة العملية ثم العودة دون التخلص من المتحكمات النصية. حساب جديد وحيد يختار صراحة بعد إنشائه؛ يلزم اختبار back/navigation على Android.


### M470 استبعاد المرسلين #7–#10
- بعد استبعاد كل الرسائل المختارة بنجاح، يُسأل المستخدم بشكل مستقل إن كان يريد استبعاد هوية المرسل. الإجراء يُحفظ بعد قبول مستقل؛ الاستبعاد الجماعي وحده لا يُنشئ قاعدة شاملة.
- قسم «المستبعدون» يعرض القائمة المشفرة ويتيح إلغاء الاستبعاد؛ الرسائل التي سبق حذفها لا تعود تلقائيًا، والرسائل الجديدة بعد الإلغاء تصبح قابلة للمراجعة.
- native store يرفض رسائل المرسل المستبعد قبل التصنيف المالي، ويزيل بقية صفه المشفر مرة واحدة مع تحديث الاستبعاد، ويطبق المنع على فحص الرسائل السابقة والمالية غير المعروفة. عند تبديل صاحب الحساب الموثق يبدأ الاستبعاد الخاص بالحساب الجديد من دون توريث قائمة غيره.
- كود التحسين يشمل Set بدل ids.contains المتكرر، والكاش في الذاكرة فقط للقائمة المشفرة، ودفعات 100؛ اختبار حمل Android حقيقي لـ500 رسالة لم يتم بعد، فلا يُعلن #10 Done نهائيًا.


## وصف #1/#2 المسترجع 2026-11-06
- #1 الخلل المقصود هو عدم عمل زر تسجيل الخروج في أجزاء التطبيق، وليس رفض كلمة المرور بعد الخروج. فحص كل مداخل الخروج، والتأكد من فصل الجلسة مع إبقاء بيانات المستخدم المشفرة دون حذف، وتقرير فشل التعليق الآمن للـSMS للمستخدم.
- #2 تحسين السحب للتحديث في شاشات التطبيق وتجنب بطء إعادة التحميل. يستمر المصدر المالي الموثّق هو الحقيقة الوحيدة؛ لا يجوز تحسين الأداء بتخطي سلامة المصدر أو إظهار بيانات قديمة بشكل مضلل.

### M470 استكمال #1/#2 بالكود
- #1: على مستوى التطبيق، callback الخروج المركزي يمنع المحاولات المتزامنة، ويستكمل التحقق من كلمة المرور المحلية والتعليق الآمن لقائمة الرسائل قبل إنهاء الجلسة، ثم يُظهر رسالة واضحة عند فشل أي خطوة دون الإيحاء بأن الحساب خرج.
- #2: Pull-to-Refresh يظل يبدأ بقراءة المصدر المالي والتحقق من سلامته، ثم يعود سريعًا إذا كانت generation وdigest وwidgetRevision متطابقة في SQLCipher؛ لا يجري هذا الاختصار في guarded legacy، وتستمر إعادة التحميل الكامل عند أي تغير مثبت.
- أضيفت اختبارات رجوع للتحقق من المسارات، لكن لا يجوز اعتماد نجاح الهاتف أو تأثير الأداء قبل القياس.
