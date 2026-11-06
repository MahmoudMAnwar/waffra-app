# وفرة — سجل التعديلات الـ32 / M470

**الفرع:** `feat/m470-approved-32-fixes-20261106` · **الأساس:** `main@1e194366e1985914c381a0d3424edc28542e6def` · **الحالة:** تنفيذ مرحلي؛ **لا تعني إضافة كود نجاح CI أو اختبار هاتف**.

## تعريف الحالة
- **Done** = نُفذ المطلوب كاملًا، داخل الـPR نفسه، واجتاز اختبارات نفس SHA وجرى التحقق من سلوكه.
- **كود + اختبار / CI قيد التحقق** = موجود على الفرع لكن ليس Done.
- **جزئي** = جزء فقط نُفذ؛ الجزء الآخر مفتوح.
- **لم يُنفذ** = لا يوجد تنفيذ معتمد للطلب في هذا PR.
- **غير مُتحقَّق منه** = وصف البند ما زال غير قابل للمطابقة، ولا يُفترض اكتماله. أوصاف البنود الـ32 معروفة الآن بعد استرجاع نص المستخدم (الأصل الكامل #13–#22 في قسم الاسترجاع الحديث).

| رقم | التعديل | الحالة الدقيقة | أثر الكود |
|---:|---|---|---|
| 1 | إصلاح تسجيل الخروج في التطبيق كله؛ مراجعة جميع أماكن تسجيل الخروج التي لا تعمل؛ مختلف عن رفض كلمة المرور المولدة | كود مسار مركزي لمنع الضغط المكرر وتقديم خطأ واضح عند فشل تعليق SMS أو إنهاء الجلسة؛ لا يمس بيانات الأموال؛ اختبار رجوع مضاف؛ CI/Android قيد الفحص | lib/main.dart + test/m470_logout_and_refresh_test.dart |
| 2 | إصلاح Pull to Refresh في شاشات التطبيق خصوصًا البطء الشديد وإعادة التحميل | كود تجنب فك JSON وإعادة بناء الواجهات إذا لم يتغير SHA/digest وجيل SQLCipher بعد قراءة آمنة؛ guarded legacy يظل كاملًا؛ اختبار رجوع مضاف؛ CI/Android قيد الفحص | lib/main.dart + test/m470_logout_and_refresh_test.dart |
| 3 | تحسين الأداء والـLoading عند إضافة دخل أو مصروف أو تحويل، مراجعة SMS، إنشاء هدف أو متكررة وأول تشغيل | جزئي: أضيف فك JSON بعد حفظ دخل/مصروف وSMS خارج UI isolate، ونقل قراءة طابور SMS المشفر والاستبعاد الجماعي بعيدًا عن خيط Android الرئيسي. باقي مسارات النقل/الهدف/المتكررة/التهيئة تحتاج قياس وتحسين. | lib/main.dart + native/WaffraMainActivity.kt + test/m470_postsave_lag_and_teach_return_test.dart |
| 4 | إزالة تقطيع الشاشة بعد اعتماد رسالة بنكية وإضافتها كعملية مالية | كود تحسين مضاف: فك السجل المالي المشفر والفئات الجديدة خارج UI isolate بعد الالتزام المالي، ثم تحديث الحالة؛ لا يُعتبر Done حتى قياس Android وتجربة حفظ ناجحة. | lib/main.dart + test/m470_postsave_lag_and_teach_return_test.dart |
| 5 | زر «الحساب» بجانب تاريخ إضافة الدخل/المصروف مع اختيار الحساب أو «إضافة حساب» | كود زر «الحساب» بمحاذاة التاريخ واختيار الحساب من قائمة الجهات موجود؛ الاختبارات والـAndroid لم يعتمدا | lib/main.dart + test/m470_sms_sender_and_rule_accuracy_test.dart |
| 6 | عند عدم وجود حسابات، زر «إضافة حساب» بجانب التاريخ ينشئ الحساب ويعود لنفس المعاملة | كود زر «إضافة حساب» عند عدم وجود حسابات والعودة لنفس نموذج العملية مع حفظ Controllers وارتباط الحساب الجديد موجود؛ يحتاج CI وتجربة Android | lib/main.dart + test/m470_sms_sender_and_rule_accuracy_test.dart |
| 7 | بعد استبعاد جميع رسائل مرسل، سؤال مستقل عن استبعاد المرسل نفسه | كود سؤال مستقل بعد الاستبعاد الجماعي الناجح لكل مرسل اكتملت رسائله؛ لا يتم حظر المرسل دون موافقة جديدة | lib/main.dart + test/m470_sms_excluded_senders_test.dart |
| 8 | إعادة تسمية قائمة المرسلين المحظورين إلى «المستبعدون» مع إلغاء الاستبعاد | كود قسم «المستبعدون» ضمن إعدادات الرسائل، عرض الأسماء واستعادة استقبال رسائل المرسل القادم؛ يحتاج CI/Android | lib/main.dart + lib/waffra_auto_sms.dart + native/WaffraMainActivity.kt |
| 9 | عدم تحليل أو عرض رسائل جديدة من مرسل مستبعد حتى إلغاء استبعاده | كود قائمة استبعاد مشفرة بنطاق حساب موثوق في Android، منع القادم قبل تحليل الرسالة وإدخالها؛ تحذير فشل قراءة مشفر؛ CI/Android معلق | native/WaffraAutoSmsStore.kt + lib/waffra_auto_sms.dart |
| 10 | تسريع تحديد واستبعاد مئات رسائل المراجعة، مثل 500 رسالة | تحسين كود اختيار 500 رسالة بـ Set وListView.builder ومعالجة 100 لكل دفعة وكاش مشفر؛ قياس الأداء الفعلي معلق | lib/main.dart + native/WaffraAutoSmsStore.kt + test/m470_sms_excluded_senders_test.dart |
| 11 | إنشاء حساب باسم المرسل تلقائيًا بعد أول SMS مالي معتمد، الرصيد صفر افتراضيًا وقبول الرصيد السالب للخصم، بلا خصم مزدوج | جزئي: اقتراح من مرسل بنك معروف، اسم المرسل مُعبأ تلقائيًا، رصيد افتتاحي صفر، إنشاء حساب SQLCipher موثق ثم تأكيد تسجيل الرسالة وربطها. الحساب والعملية لا يزالان معاملتين منفصلتين، ولم يتم اعتماد سيناريو الذرية المطلوبة على جهاز حقيقي؛ حفظ الحساب يسبق حفظ أول SMS. | lib/main.dart + lib/waffra_new_account_dialog.dart + test/m470_sms_first_sender_account_test.dart |
| 12 | إصلاح تداخل العدد وكلمة «رسائل» في قائمة المرسلين وصياغة «3 رسائل بانتظار المراجعة» | كود إصلاح مضاف إلى Home مع Directionality وعزل عدد الرسائل؛ اختبار رجوع مضاف؛ CI/Android معلق | lib/main.dart + test/m470_sms_sender_and_rule_accuracy_test.dart |
| 13 | عند مراجعة SMS تحويل من حساب ••••8308 إلى ••••9288 تظهر «تحقق من عملة الرسالة قبل تسجيل التحويل» رغم أن الرسالة توضح مبلغ التحويل ورسومًا منفصلة قدرها 0.58 ريال؛ المطلوب تدقيق العملة الرئيسية وفصل الرسوم والسماح بمراجعة الحسابين إذا كانت SAR مؤكدة، وعدم قبول العملات المجهولة | **مفتوح وظيفيًا:** مسار `_reviewSmsAccountTransfer` ما زال يرفض عند `WaffraSmsCurrencies.requiresReviewForSarLedger(body)` قبل فتح نموذج التحويل. لا يوجد اختبار مثبت لحالة AlinmaPay الأصلية ورسوم 0.58 ريال، ولا يجوز bypass للتحقق المالي | lib/main.dart + lib/waffra_sms_multicurrency_review.dart + lib/waffra_bank_sms_facts.dart |
| 14 | تشويه عرض النص العربي واتجاه الأرقام ورمز الريال، خصوصًا «رسوم مستقطعة»، في شاشة مراجعة الرسالة؛ يجب عدم الخلط بين الرسوم ومبلغ التحويل، وألا تظهر «خصم» ككلمة اقتراح لتحويل | **جزئي/غير مدمج:** إصلاح حدود الكلمات العربية ورمز الريال موجود في الفرع المنفصل `fix/m470-global-rtl-currency-text-20261106` لا في PR #395؛ مطلوب دمجه دون تعارض، اختبارات bidi وعرض حقيقي، والتحقق من فصل الرسوم | lib/waffra_riyal_symbol.dart + lib/waffra_bank_sms_facts.dart + lib/main.dart (فرع مستقل) |
| 15 | الرجوع من «علّم وفرة» في تحويل SMS؛ متجاوز بالقرار النهائي بحذف الزر من كل مراجعات الرسائل | تم حذف الزر ومسار Teach من مراجعة SMS في #395؛ CI/Android معلق | lib/main.dart + test/m470_postsave_lag_and_teach_return_test.dart |
| 16 | عدم اقتراح قاعدة لا تطابق رسالة التحويل الأصلية؛ الكلمات والمعاينة يجب أن تتفق مع المرسل والنوع | كود إصلاح مضاف إلى شاشة القواعد لمنع fallback عام والتحقق من النوع/المرسل/النص؛ اختبار رجوع مضاف؛ CI/Android معلق | lib/waffra_sms_rule_settings_page.dart + test/m470_sms_sender_and_rule_accuracy_test.dart |
| 17 | الرجوع من «علّم وفرة» في دخل/مصروف SMS؛ متجاوز بالقرار النهائي بحذف الزر | كود إزالة زر Teach ومنع فتح صفحة القواعد قسريًا بعد الحفظ موجود داخل #395؛ CI/Android معلق | lib/main.dart + test/m462_smart_sms_rule_review_test.dart |
| 18 | أول ضغط على «مراجعة العملية» بعد تحليل SMS يسبب Refresh/رجوع للرئيسية، بينما الضغط الثاني يفتح مراجعة الدخل/المصروف | **مفتوح وغير مثبت إصلاحه:** لا يكفي وجود مسار Review؛ يلزم اختبار أول ضغط، منع إعادة بناء/إغلاق المراجعة بسبب Refresh الخلفية والعودة للنموذج نفسه | lib/main.dart (SMS review navigation) |
| 19 | بعد «إضافة معاملة» ثم الرجوع لا يقبل Dropdown القسم الفرعي أي اختيار؛ المطلوب استقرار اختيار القسم الرئيسي والفرعي وعدم فقدهما | **مفتوح للتحقق:** لم يُثبت أصل المشكلة أو نجاح إصلاحها باختبار Widget عملي بعد back/reopen؛ يجب إصلاح state/controller وربط اختيار القسم الفرعي بوضوح | lib/main.dart (manual/SMS editor) |
| 20 | تعلّم تلقائي آمن بعد تأكيد دخل/مصروف/تحويل/استبعاد رسالة، بدون طلب «علّم وفرة»، وإضافة كلمات للقواعد الموجودة لا إنشاء مكرر | جزئي بالكود في #395: زر Teach أُلغي من مراجعة SMS، لا إجبار لصفحة القواعد، التعلم بعد SMS hash مؤكد أو تحويل محفوظ أو استبعاد رسالة مؤكد؛ اختبار فعلي على Android/مسارات فشل الحفظ لا يزال مفتوحًا | lib/main.dart + lib/waffra_sms_local_rules.dart + test/m470_postsave_lag_and_teach_return_test.dart |
| 21 | فحص تشويه الكلمات عبر كل شاشات وفرة، خصوصًا تفسير «رس» في «رسالة/رسائل/رسوم» كرمز ريال، وفحص حدود Regex واتجاه النص، ثم إصلاح كافة المواقع المتأثرة | **كود على فرع منفصل فقط:** `fix/m470-global-rtl-currency-text-20261106` يحتوي تغييرات في 9 ملفات تخص عرض/تحليل العملة واختبارين؛ **لم يدخل بعد PR #395 أو main**، ولم يُقبل اختبار الهاتف/تداخل العناصر | lib/waffra_riyal_symbol.dart + ملفات تحليل SMS والـAI (الفرع المنفصل) |
| 22 | بعد خروج المستخدم لتطبيق آخر، إذا مرّت دقيقة يطلب البصمة عند العودة، ويعرض أمامها صفحة خضراء فقط لا القوائم/الدروب داون تحته، وبعد التحقق يعود لنفس آخر شاشة ونفس مسودة الإدخال؛ مع تسجيل خروج آمن | **جزئي:** `WaffraIdleBiometricOverlay` يغطي Navigator بعد 60 ثانية **داخل التطبيق وهو في foreground** ويحافظ على المسار؛ لكن `_didChangeAppLifecycleState` يغيّر `locked=true` فور الخلفية، فيُعاد بناء جذر الدخول بدل الانتظار 60ث والحفاظ المؤكد على القوائم. يحتاج توحيد مسار القفل واختبارات background/restore Android | lib/waffra_idle_biometric_overlay.dart + lib/waffra_mandatory_biometric_gate.dart + lib/main.dart |
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


## تصحيح رسمي للتطابق مع النص الأصلي المرسل — 6 نوفمبر 2026
**استُرجعت الآن كل أوصاف الـ32 بندًا.** هذا التصحيح هو المرجع الأحدث، وأي ملاحظات تاريخية أدناه تقول إن #15 أو #17–#21 مجهولة أو تنسب الرجوع من «علّم وفرة» إلى #14 بدل #15 تُعد **قديمة ولا تُستخدم في تقرير الإنجاز**. الملفات التي لم تُدمج لا تُحسب Done.
- #13: رفض رسالة تحويل بنكي صحيحة (مثال حساب ••••8308 إلى ••••9288 ورسوم 0.58 SAR) بسبب فحص العملة قبل فتح المراجعة؛ المطلوب عملة مؤكدة للمبلغ الأساسي + رسم منفصل، دون قبول عملات غير معروفة.
- #14: تشويه نص «رسوم مستقطعة» ورمز الريال والأرقام أثناء مراجعة الرسائل، ومراجعة عدم اقتراح «خصم» لتحويل. يختلف عن #15.
- #15: الرجوع من «علّم وفرة» **للتحويل** إلى نفس SMS بعد الحفظ أو Back، دون إعادة فحص غير ضروري.
- #16: قاعدة تحويل بكلمة غير مطابقة مثل «خصم» ومعاينة صفر رسالة؛ يجب مطابقة النص/المرسل/النوع.
- #17: نفس رجوع «علّم وفرة» لكن **لدخل/مصروف** مع حفظ السياق.
- #18: منع رجوع أول ضغطة «مراجعة العملية» للرئيسية عند تحديث الخلفية.
- #19: قبول اختيار القسم الفرعي بعد العودة/الفتح مجددًا دون فقد حالة الحقول.
- #20: بعد نجاح حفظ دخل/مصروف/تحويل يتعلم وفرة تلقائيًا من الكلمات الآمنة في **قواعد النوع الموجودة** حتى من غير «علّم وفرة»، دون قاعدة مكررة أو تخزين معرفات حساسة؛ استبعاد المرسل الكامل يتطلب موافقة.
- #21: مراجعة التشويه عبر التطبيق؛ إصلاح حدود كلمات الريال والعملات موجود في **فرع مستقل** `fix/m470-global-rtl-currency-text-20261106` وليس في PR #395 بعد. يجب تقييم الدمج والتعارضات والاختبارات.
- #22: مدة خارج التطبيق **60 ثانية** مع واجهة بصمة خضراء معتمة وأمامها لا تظهر الدروب داون، والرجوع لنفس المسار/المسودة؛ الموجود حاليًا قفل فور الخلفية بالإضافة إلى مؤقت 60ث داخل foreground، لذا ليس مطابقًا بالكامل.
**حالة الاسترجاع: 32/32 وصف معروف؛ 0 بنود مجهولة.** هذا لا يعني أن 32/32 منفذة أو مختبرة. اطلب اختبار قفل الخلفية على الهاتف وتوثيق 13/18/19/20/21 قبل أي Done.

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


## مطابقة قائمة المستخدم الكاملة المسترجعة جزئيًا — M470 2026-11-06
- ثبتت أوصاف #3، #13، #14 بدل وضعها مجهولة، مع توضيح أن نص العطل الأصلي لـ#13/#14 جزئي.
- #11: إنشاء الحساب من مراجعة SMS يقتصر على دخل/مصروف مرسل بنكي معروف دون حساب موثق له. المستخدم يختار إنشاء الحساب أولًا، ويؤكد الاسم والرصيد الافتراضي 0 ريال في نموذج مستقل. تُحفظ هوية البنك وآخر أربعة أرقام (إن اختارها) في SQLCipher عبر نفس writer الآمن المعتمد. بعد إعادة قراءة حساباته من SQLCipher، يُقترح الحساب الجديد للرسالة داخل اختيار الحساب؛ لا تُسجّل العملية المالية دون موافقة ثانية وصلاحية الكاتب المالية الحالية. هذا لا يحقق معاملة SQLCipher واحدة تجمع إنشاء الحساب وحفظ الرسالة، ويستمر الحساب المضاف صراحةً لو ألغى المستخدم العملية.
- #3 أداء فتح التطبيق والأهداف والمتكررة ودخل/مصروف/تحويل والسحب والرسائل ليس Done حتى يوجد قياس حقيقي على الجهاز وإثبات عدم فقد أي مسودة.
- ما زالت البنود #4 و#15 و#17 و#18 و#19 و#20 و#21 غير مسترجعة. لن تُختلق حالات تنفيذ لها.

### نتيجة مراجعة النص الأصلي للمحادثة في 6 نوفمبر
- تم تحديد #4 أخيرًا: اللاج بعد حفظ SMS معتمدة؛ لم يعد مفقود النص. وتم تفصيل #3 في شاشات الإدخال اليدوي والتحويل والأهداف والمتكررة وأول تشغيل؛ ما زال جزئيًا.
- #11 وفق طلب المستخدم **اسم المرسل نفسه مسبقًا** ورصيد صفر. شرط الرصيد السالب مدعوم بالفعل بحسابات الرصيد من SQLCipher، لكن لا تزال معاملة إنشاء الحساب ومعاملة SMS المنفصلة **ليستا ذرّيتين كإجراء واحد**؛ وموافقة المستخدم على الأولى لا تعني إثبات الثانية. المطلوب الحالي يستمر جزئيًا حتى اختبار/تنفيذ الذرية أو اتخاذ قرار صريح مختلف.
- #14: كود الرجوع يعيد المستخدم إلى الرسالة ذات ID نفسه إذا استمرت في المراجعة، ولا يعيد فحص التاريخ عند الخروج بدون حفظ. لا تعتبره مكتملًا قبل UAT.
- الأكواد والتغييرات موجودة في PR #395 ولا تعادل الاختبار الناجح على هاتف المستخدمين؛ نتائج exact-head CI مستقلة عن الحالة الوظيفية.

## 6 نوفمبر — علاج 6 Workflows فاشلة بسبب 4 اختبارات قديمة على SHA b546774
- كانت النتيجة النهائية 38 نجاح و6 فشل من 44 Workflow. اختبار Flutter الشامل سجل 2364 نجاحًا و4 إخفاقات مصدرية: M206 (الـMaterialApp.builder بعد إضافة قفل البصمة)، M372 وM398 (استبدال تاريخ بعرض ثابت بتاريخ وحساب متجاورين)، وM470 #9 (قناة استبعاد مرسل أصبحت تعمل خارج Android UI thread).
- صُححت توقعات الاختبارات لتفحص وجود الغلاف الجديد مع الحفاظ على Navigator والـRTL، والتاريخ والحساب جنب بعض مع بقاء الميزانيات، واستخدام executor + رد UI في استبعاد المرسل وإعادة استقباله. لم تتغير أكواد الإنتاج، ولم تخفف قواعد SQLCipher أو سلامة الرصيد.
- الحالات مرشحة لحين مرور Full Flutter suite وM385 على آخر Commit؛ استمرار البنود #3/#10/#11 جزئي حتى benchmark وذرية أول SMS وقبول Android.


## اعتماد القرار النهائي — حذف «علّم وفرة» من كل مراجعات SMS
- بنود الرجوع #15/#17 ملغاة وظيفيًا، والبديل هو مراجعة رسالة واحدة مباشرة مع التعلم التلقائي بعد الحفظ المؤكد. مسار التحويل لا يشترط إنشاء قاعدة قبل المراجعة. استبعاد الرسالة لا يحظر المرسل كله. صفحة القواعد اليدوية ما زالت متاحة من إعدادات الرسائل.
- التغيير موجود في كود PR #395؛ لا إعلان Done دون نجاح اختبارات آخر SHA وتجربة Android.
