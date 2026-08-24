import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/local_store.dart';
import 'domain/validation.dart';
import 'ird/ird_enrollment_page.dart';
import 'models.dart';
import 'ocr/bill_ocr.dart';
import 'services/firebase_service.dart';

class KarUpaharApp extends StatefulWidget {
  const KarUpaharApp({super.key, required this.store, required this.firebase});

  final LocalStore store;
  final FirebaseService firebase;

  @override
  State<KarUpaharApp> createState() => _KarUpaharAppState();
}

class _KarUpaharAppState extends State<KarUpaharApp> {
  AppLanguage _language = AppLanguage.ne;

  @override
  void initState() {
    super.initState();
    widget.store.getLanguage().then((language) {
      if (mounted) setState(() => _language = language);
    });
  }

  void _setLanguage(AppLanguage language) {
    if (_language == language) return;
    setState(() => _language = language);
    widget.store.saveLanguage(language);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Kar Upahar',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffb3262d)),
          useMaterial3: true,
          inputDecorationTheme:
              const InputDecorationTheme(border: OutlineInputBorder()),
          cardTheme:
              const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
        ),
        home: FutureBuilder<UserProfile?>(
          future: widget.store.getProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.data == null) {
              return ProfilePage(
                language: _language,
                onLanguageChanged: _setLanguage,
                onSaved: (profile) async {
                  await widget.store.saveProfile(profile);
                  setState(() {});
                },
              );
            }
            return HomeShell(
              profile: snapshot.data!,
              language: _language,
              store: widget.store,
              firebase: widget.firebase,
              onLanguageChanged: _setLanguage,
              onProfileChanged: () => setState(() {}),
            );
          },
        ),
      );
}

class Copy {
  const Copy(this.language);
  final AppLanguage language;
  bool get ne => language == AppLanguage.ne;
  String t(String nepali, String english) => ne ? nepali : english;
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .22),
        child: Image.asset(
          'assets/images/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.onSaved,
    this.initial,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<UserProfile> onSaved;
  final UserProfile? initial;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _address;
  late AppLanguage _language;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name);
    _mobile = TextEditingController(text: widget.initial?.mobile);
    _address = TextEditingController(text: widget.initial?.address);
    _language = widget.language;
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      _language = widget.language;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = Copy(_language);
    return Scaffold(
      appBar: AppBar(
        title: Text(copy.t('कर उपहार', 'Tax Lottery')),
        actions: [
          SegmentedButton<AppLanguage>(
            segments: const [
              ButtonSegment(value: AppLanguage.ne, label: Text('ने')),
              ButtonSegment(value: AppLanguage.en, label: Text('EN')),
            ],
            selected: {_language},
            onSelectionChanged: (value) {
              setState(() => _language = value.first);
              widget.onLanguageChanged(value.first);
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 88)),
                    const SizedBox(height: 16),
                    Text(
                        copy.t('आफ्नो विवरण सुरक्षित गर्नुहोस्',
                            'Complete your profile'),
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                        copy.t('यो विवरण यस उपकरणमा मात्र रहन्छ।',
                            'These details stay on this device.'),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextFormField(
                        controller: _name,
                        decoration: InputDecoration(
                            labelText: copy.t('पूरा नाम', 'Full name')),
                        validator: validateName,
                        textInputAction: TextInputAction.next),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: _mobile,
                        decoration: InputDecoration(
                            labelText: copy.t('मोबाइल नम्बर', 'Mobile number'),
                            prefixText: '+977 '),
                        keyboardType: TextInputType.phone,
                        validator: validateNepalMobile,
                        textInputAction: TextInputAction.next),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: _address,
                        decoration: InputDecoration(
                            labelText: copy.t('ठेगाना', 'Address')),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Address is required'
                            : null),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        widget.onSaved(UserProfile(
                            name: _name.text.trim(),
                            mobile: normalizeNepalMobile(_mobile.text),
                            address: _address.text.trim()));
                        if (widget.initial != null) Navigator.pop(context);
                      },
                      child: Text(
                          copy.t('विवरण सुरक्षित गर्नुहोस्', 'Save profile')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.profile,
    required this.language,
    required this.store,
    required this.firebase,
    required this.onLanguageChanged,
    required this.onProfileChanged,
  });

  final UserProfile profile;
  final AppLanguage language;
  final LocalStore store;
  final FirebaseService firebase;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onProfileChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;
  var _refresh = 0;

  void _reload() => setState(() => _refresh++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
          profile: widget.profile,
          language: widget.language,
          store: widget.store,
          firebase: widget.firebase,
          onChanged: _reload),
      BillsPage(
          key: ValueKey(_refresh),
          language: widget.language,
          store: widget.store,
          onChanged: _reload),
      WinnersPage(language: widget.language, firebase: widget.firebase),
    ];
    final copy = Copy(widget.language);
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8),
          child: AppLogo(size: 40),
        ),
        title: Text(copy.t('कर उपहार', 'Kar Upahar')),
        actions: [
          IconButton(
            tooltip: copy.t('सेटिङ', 'Settings'),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfilePage(
                          language: widget.language,
                          initial: widget.profile,
                          onLanguageChanged: widget.onLanguageChanged,
                          onSaved: (profile) async {
                            await widget.store.saveProfile(profile);
                            widget.onProfileChanged();
                          },
                        ))),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: copy.t('गृह', 'Home')),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: copy.t('बिलहरू', 'Bills')),
          NavigationDestination(
              icon: const Icon(Icons.emoji_events_outlined),
              selectedIcon: const Icon(Icons.emoji_events),
              label: copy.t('विजेता', 'Winners')),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage(
      {super.key,
      required this.profile,
      required this.language,
      required this.store,
      required this.firebase,
      required this.onChanged});
  final UserProfile profile;
  final AppLanguage language;
  final LocalStore store;
  final FirebaseService firebase;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final copy = Copy(language);
    return FutureBuilder<List<BillEntry>>(
      future: store.getBills(),
      builder: (context, snapshot) {
        final active =
            snapshot.data?.where((bill) => bill.isActive).length ?? 0;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(copy.t('नमस्ते, ${profile.name}', 'Hello, ${profile.name}'),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 18),
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  const Icon(Icons.add_a_photo_outlined, size: 58),
                  const SizedBox(height: 12),
                  Text(copy.t('नयाँ बिल थप्नुहोस्', 'Add a new bill'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(copy.t('रु १०० भन्दा बढीको सक्कली बिल',
                      'A genuine bill worth more than Rs 100')),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () async {
                      final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => BillEntryPage(
                                  profile: profile,
                                  language: language,
                                  store: store,
                                  firebase: firebase)));
                      if (changed == true) onChanged();
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: Text(copy.t('फोटो खिच्नुहोस्', 'Take photo')),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Card(
                child: ListTile(
                    leading: const Icon(Icons.confirmation_number_outlined),
                    title: Text(copy.t('सक्रिय कुपन', 'Active coupons')),
                    trailing: Text('$active',
                        style: Theme.of(context).textTheme.headlineSmall))),
            const SizedBox(height: 12),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(copy.t(
                        'पुरस्कार दाबी गर्न सक्कल बिल सुरक्षित राख्नुहोस्। फोटो मात्र पर्याप्त हुँदैन।',
                        'Keep the original paper bill to claim a prize. A photograph alone is not sufficient.')))),
          ],
        );
      },
    );
  }
}

class BillEntryPage extends StatefulWidget {
  const BillEntryPage(
      {super.key,
      required this.profile,
      required this.language,
      required this.store,
      required this.firebase,
      this.ocrService = const BillOcrService()});
  final UserProfile profile;
  final AppLanguage language;
  final LocalStore store;
  final FirebaseService firebase;
  final BillOcrService ocrService;

  @override
  State<BillEntryPage> createState() => _BillEntryPageState();
}

class _BillEntryPageState extends State<BillEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _billNumber = TextEditingController();
  final _pan = TextEditingController();
  final _date = TextEditingController();
  final _amount = TextEditingController();
  final _digitalCoupon = TextEditingController();
  PaymentMethod _payment = PaymentMethod.cash;
  String? _photoPath;
  var _busy = false;
  var _scanning = false;
  var _ocrState = _BillOcrState.idle;
  var _panScanned = false;
  var _dateScanned = false;
  var _amountScanned = false;
  var _scanGeneration = 0;

  @override
  void dispose() {
    _billNumber.dispose();
    _pan.dispose();
    _date.dispose();
    _amount.dispose();
    _digitalCoupon.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto(ImageSource source) async {
    final image = await ImagePicker()
        .pickImage(source: source, imageQuality: 88, maxWidth: 2200);
    if (image == null || !mounted) return;

    final generation = ++_scanGeneration;
    setState(() {
      if (_panScanned) {
        _pan.clear();
        _panScanned = false;
      }
      if (_dateScanned) {
        _date.clear();
        _dateScanned = false;
      }
      if (_amountScanned) {
        _amount.clear();
        _amountScanned = false;
      }
      _photoPath = image.path;
      _scanning = true;
      _ocrState = _BillOcrState.scanning;
    });

    try {
      final result = await widget.ocrService.scan(image.path);
      if (!mounted || generation != _scanGeneration) return;
      setState(() {
        if (_pan.text.trim().isEmpty && result.panNumber != null) {
          _pan.text = result.panNumber!;
          _panScanned = true;
        }
        if (_date.text.trim().isEmpty && result.billDateAd != null) {
          _date.text = result.billDateAd!;
          _dateScanned = true;
        }
        if (_amount.text.trim().isEmpty && result.totalAmount != null) {
          _amount.text = result.totalAmount!;
          _amountScanned = true;
        }
        _scanning = false;
        _ocrState = result.detectedFieldCount == 3
            ? _BillOcrState.complete
            : result.detectedFieldCount > 0
                ? _BillOcrState.partial
                : _BillOcrState.failed;
      });
    } catch (_) {
      if (!mounted || generation != _scanGeneration) return;
      setState(() {
        _scanning = false;
        _ocrState = _BillOcrState.failed;
      });
    }
  }

  Future<void> _submit() async {
    if (_photoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Take or select a bill photo first.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final date = DateTime.tryParse(_date.text.trim());
    if (date == null || date.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid bill date in YYYY-MM-DD format.')));
      return;
    }
    if (_payment == PaymentMethod.cash && !widget.firebase.submissionEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'IRD submission is temporarily unavailable. Your bill was not sent.')));
      return;
    }
    setState(() => _busy = true);
    final retainedPath = await widget.store.retainPhoto(_photoPath!);
    var bill = await widget.store.saveBill(BillEntry(
      billNumber: _billNumber.text.trim(),
      sellerPan: _pan.text.trim(),
      billDate: date,
      amount: double.parse(_amount.text.replaceAll(',', '')),
      paymentMethod: _payment,
      imagePath: retainedPath,
      status: EnrollmentStatus.submitting,
      createdAt: DateTime.now(),
    ));
    if (!mounted) return;

    if (_payment == PaymentMethod.digital) {
      final coupon = normalizeCoupon(_digitalCoupon.text);
      bill = bill.copyWith(
        status: EnrollmentStatus.submitted,
        coupon: coupon.isEmpty ? null : coupon,
        serverMessage:
            'Digital payment saved. Enrollment is handled by the payment provider.',
      );
      await widget.store.updateBill(bill);
      if (coupon.isNotEmpty) {
        await widget.firebase.registerCoupon(coupon, nextDrawDate(date));
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.verified_outlined,
              color: Colors.green, size: 52),
          title: Text(Copy(widget.language)
              .t('डिजिटल बिल सुरक्षित भयो', 'Digital bill saved')),
          content: Text(coupon.isEmpty
              ? 'Your payment provider handles IRD enrollment. You can add the coupon later by saving a new record when it is available.'
              : 'Coupon: $coupon'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
      return;
    }

    if (widget.firebase.externalBrowserFallback) {
      await launchUrl(Uri.parse(widget.firebase.portalUrl),
          mode: LaunchMode.externalApplication);
      bill = bill.copyWith(
          status: EnrollmentStatus.uncertain,
          serverMessage:
              'Complete and verify submission in the official browser.');
      await widget.store.updateBill(bill);
      if (mounted) Navigator.pop(context, true);
      return;
    }

    final result = await Navigator.push<IrdEnrollmentResult>(
        context,
        MaterialPageRoute(
            builder: (_) => IrdEnrollmentPage(
                bill: bill,
                profile: widget.profile,
                portalUrl: widget.firebase.portalUrl)));
    if (result == null) {
      bill = bill.copyWith(
          status: EnrollmentStatus.uncertain,
          serverMessage:
              'Submission was closed before a result was confirmed.');
    } else if (result.success && result.coupon != null) {
      bill = bill.copyWith(
          status: EnrollmentStatus.submitted,
          coupon: result.coupon,
          serverMessage: result.message);
      await widget.firebase.registerCoupon(result.coupon!, nextDrawDate(date));
    } else {
      bill = bill.copyWith(
          status: EnrollmentStatus.rejected,
          serverMessage: result.message ?? 'IRD rejected the enrollment.');
    }
    await widget.store.updateBill(bill);
    if (!mounted) return;
    setState(() => _busy = false);
    if (bill.status == EnrollmentStatus.submitted) {
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                icon: const Icon(Icons.check_circle,
                    color: Colors.green, size: 52),
                title: const Text('Enrollment successful'),
                content: Text(
                    'Coupon: ${bill.coupon}\n\nKeep the original paper bill.'),
                actions: [
                  FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'))
                ],
              ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(bill.serverMessage ?? 'Submission could not be verified.')));
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final copy = Copy(widget.language);
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('बिल विवरण', 'Bill details'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Card.filled(
                clipBehavior: Clip.antiAlias,
                child: _photoPath == null
                    ? const Center(child: Icon(Icons.receipt_long, size: 64))
                    : Image.file(File(_photoPath!), fit: BoxFit.cover),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton.icon(
                  onPressed:
                      _busy ? null : () => _choosePhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(copy.t('क्यामेरा', 'Camera'))),
              TextButton.icon(
                  onPressed:
                      _busy ? null : () => _choosePhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: Text(copy.t('ग्यालेरी', 'Gallery'))),
            ]),
            if (_ocrState != _BillOcrState.idle) ...[
              const SizedBox(height: 4),
              _OcrStatusCard(state: _ocrState, language: widget.language),
            ],
            const SizedBox(height: 8),
            TextFormField(
                controller: _billNumber,
                decoration: InputDecoration(
                    labelText: copy.t('बिल नम्बर', 'Bill number')),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Bill number is required'
                    : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _pan,
                decoration: InputDecoration(
                    labelText: copy.t(
                        'विक्रेताको PAN/VAT नम्बर', 'Seller PAN/VAT number'),
                    suffixIcon: _panScanned
                        ? const Icon(Icons.document_scanner_outlined)
                        : null),
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  if (_panScanned) setState(() => _panScanned = false);
                },
                validator: validatePan),
            const SizedBox(height: 12),
            TextFormField(
                controller: _date,
                decoration: InputDecoration(
                    labelText: copy.t('बिल मिति (AD)', 'Bill date (AD)'),
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: _dateScanned
                        ? const Icon(Icons.document_scanner_outlined)
                        : null),
                keyboardType: TextInputType.datetime,
                onChanged: (_) {
                  if (_dateScanned) setState(() => _dateScanned = false);
                },
                validator: (value) => DateTime.tryParse(value ?? '') == null
                    ? 'Use YYYY-MM-DD'
                    : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _amount,
                decoration: InputDecoration(
                    labelText: copy.t('जम्मा रकम', 'Total amount'),
                    prefixText: 'Rs ',
                    suffixIcon: _amountScanned
                        ? const Icon(Icons.document_scanner_outlined)
                        : null),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  if (_amountScanned) setState(() => _amountScanned = false);
                },
                validator: validateAmount),
            const SizedBox(height: 12),
            SegmentedButton<PaymentMethod>(
              segments: [
                ButtonSegment(
                    value: PaymentMethod.cash,
                    label: Text(copy.t('नगद', 'Cash')),
                    icon: const Icon(Icons.payments_outlined)),
                ButtonSegment(
                    value: PaymentMethod.digital,
                    label: Text(copy.t('डिजिटल', 'Digital')),
                    icon: const Icon(Icons.qr_code))
              ],
              selected: {_payment},
              onSelectionChanged: _busy
                  ? null
                  : (value) => setState(() => _payment = value.first),
            ),
            if (_payment == PaymentMethod.digital) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _digitalCoupon,
                decoration: InputDecoration(
                  labelText:
                      copy.t('कुपन कोड (वैकल्पिक)', 'Coupon code (optional)'),
                  helperText: copy.t(
                    'डिजिटल भुक्तानी प्रदायकले दिएको भए मात्र लेख्नुहोस्।',
                    'Enter it only if your payment provider supplied one.',
                  ),
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
            const SizedBox(height: 18),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(copy.t(
                        'मैले प्रविष्ट गरेको विवरण सही छ र यो व्यक्तिगत खरिद हो।',
                        'I confirm these details are accurate and this is a personal purchase.')))),
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: _busy || _scanning ? null : _submit,
                icon: _busy || _scanning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_payment == PaymentMethod.digital
                        ? Icons.save_outlined
                        : Icons.open_in_browser),
                label: Text(_payment == PaymentMethod.digital
                    ? copy.t(
                        'डिजिटल बिल सुरक्षित गर्नुहोस्', 'Save digital bill')
                    : copy.t('IRD मा पेश गर्नुहोस्', 'Continue to IRD'))),
          ],
        ),
      ),
    );
  }
}

enum _BillOcrState { idle, scanning, complete, partial, failed }

class _OcrStatusCard extends StatelessWidget {
  const _OcrStatusCard({required this.state, required this.language});

  final _BillOcrState state;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final copy = Copy(language);
    final (icon, text, color) = switch (state) {
      _BillOcrState.scanning => (
          Icons.document_scanner_outlined,
          copy.t('बिल पढिँदैछ…', 'Reading bill…'),
          Theme.of(context).colorScheme.primary,
        ),
      _BillOcrState.complete => (
          Icons.auto_awesome,
          copy.t('PAN, मिति र जम्मा रकम भेटियो। कृपया जाँच गर्नुहोस्।',
              'PAN, date and total were found. Please verify them.'),
          Colors.green,
        ),
      _BillOcrState.partial => (
          Icons.fact_check_outlined,
          copy.t('केही विवरण भेटियो। बाँकी विवरण आफैं भर्नुहोस्।',
              'Some details were found. Enter the remaining fields manually.'),
          Colors.orange,
        ),
      _BillOcrState.failed => (
          Icons.edit_note_outlined,
          copy.t('विवरण पढ्न सकिएन। कृपया आफैं भर्नुहोस्।',
              'Could not read the details. Please enter them manually.'),
          Theme.of(context).colorScheme.error,
        ),
      _BillOcrState.idle => (
          Icons.document_scanner_outlined,
          '',
          Theme.of(context).colorScheme.primary,
        ),
    };

    return Card.filled(
      color: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (state == _BillOcrState.scanning)
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class BillsPage extends StatefulWidget {
  const BillsPage(
      {super.key,
      required this.language,
      required this.store,
      required this.onChanged});
  final AppLanguage language;
  final LocalStore store;
  final VoidCallback onChanged;

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  var _active = true;

  Future<void> _deleteBill(BillEntry bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved bill?'),
        content: const Text(
            'The local photograph and entry will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.deleteBill(bill);
    if (mounted) setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final copy = Copy(widget.language);
    return Column(children: [
      const SizedBox(height: 12),
      SegmentedButton<bool>(segments: [
        ButtonSegment(value: true, label: Text(copy.t('सक्रिय', 'Active'))),
        ButtonSegment(value: false, label: Text(copy.t('इतिहास', 'History')))
      ], selected: {
        _active
      }, onSelectionChanged: (value) => setState(() => _active = value.first)),
      Expanded(
          child: FutureBuilder<List<BillEntry>>(
        future: widget.store.getBills(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final bills =
              snapshot.data!.where((bill) => bill.isActive == _active).toList();
          if (bills.isEmpty) {
            return Center(child: Text(copy.t('कुनै बिल छैन', 'No bills here')));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              return _BillEntryCard(
                bill: bill,
                language: widget.language,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BillDetailsPage(
                      bill: bill,
                      language: widget.language,
                    ),
                  ),
                ),
                onDelete: () => _deleteBill(bill),
              );
            },
          );
        },
      )),
    ]);
  }
}

class _BillEntryCard extends StatelessWidget {
  const _BillEntryCard({
    required this.bill,
    required this.language,
    required this.onTap,
    required this.onDelete,
  });

  final BillEntry bill;
  final AppLanguage language;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final copy = Copy(language);
    final active = bill.isActive;
    final accent = active
        ? const Color(0xff087f5b)
        : bill.status == EnrollmentStatus.rejected
            ? Theme.of(context).colorScheme.error
            : const Color(0xff6b7280);
    final statusLabel = switch (bill.status) {
      EnrollmentStatus.submitted => copy.t('सक्रिय', 'Active'),
      EnrollmentStatus.rejected => copy.t('अस्वीकृत', 'Rejected'),
      EnrollmentStatus.uncertain => copy.t('पुष्टि बाँकी', 'Unconfirmed'),
      EnrollmentStatus.winner => copy.t('विजेता', 'Winner'),
      EnrollmentStatus.notSelected => copy.t('नपरेको', 'Not selected'),
      EnrollmentStatus.draft => copy.t('मस्यौदा', 'Draft'),
      EnrollmentStatus.submitting => copy.t('पेश हुँदै', 'Submitting'),
    };

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: -22,
              top: -24,
              child: Icon(
                bill.paymentMethod == PaymentMethod.digital
                    ? Icons.qr_code_2
                    : Icons.receipt_long,
                size: 122,
                color: accent.withValues(alpha: .055),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: .075),
                    Theme.of(context).colorScheme.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(bill.imagePath),
                          width: 66,
                          height: 76,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 66,
                            height: 76,
                            color: accent.withValues(alpha: .12),
                            child: const Icon(Icons.receipt_long),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -7,
                        bottom: -5,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          child: Icon(
                            bill.paymentMethod == PaymentMethod.digital
                                ? Icons.qr_code
                                : Icons.payments_outlined,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(active ? Icons.check_circle : Icons.info,
                                      size: 14, color: accent),
                                  const SizedBox(width: 5),
                                  Text(statusLabel,
                                      style: TextStyle(
                                          color: accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            PopupMenuButton<String>(
                              tooltip: copy.t('थप विकल्प', 'More options'),
                              onSelected: (value) {
                                if (value == 'delete') onDelete();
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [
                                    const Icon(Icons.delete_outline),
                                    const SizedBox(width: 10),
                                    Text(copy.t('मेटाउनुहोस्', 'Delete')),
                                  ]),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          bill.coupon ??
                              copy.t('बिल ${bill.billNumber}',
                                  'Bill ${bill.billNumber}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Icon(Icons.currency_rupee, size: 16, color: accent),
                            Text(bill.amount.toStringAsFixed(2),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 12),
                            const Icon(Icons.calendar_today_outlined, size: 15),
                            const SizedBox(width: 5),
                            Text(bill.billDate
                                .toIso8601String()
                                .substring(0, 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BillDetailsPage extends StatelessWidget {
  const BillDetailsPage({
    super.key,
    required this.bill,
    required this.language,
  });

  final BillEntry bill;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final copy = Copy(language);
    final active = bill.isActive;
    final accent = active
        ? const Color(0xff087f5b)
        : bill.status == EnrollmentStatus.rejected
            ? Theme.of(context).colorScheme.error
            : const Color(0xff6b7280);
    final statusLabel = switch (bill.status) {
      EnrollmentStatus.submitted => copy.t('सक्रिय', 'Active'),
      EnrollmentStatus.rejected => copy.t('अस्वीकृत', 'Rejected'),
      EnrollmentStatus.uncertain => copy.t('पुष्टि बाँकी', 'Unconfirmed'),
      EnrollmentStatus.winner => copy.t('विजेता', 'Winner'),
      EnrollmentStatus.notSelected => copy.t('नपरेको', 'Not selected'),
      EnrollmentStatus.draft => copy.t('मस्यौदा', 'Draft'),
      EnrollmentStatus.submitting => copy.t('पेश हुँदै', 'Submitting'),
    };
    final paymentLabel = bill.paymentMethod == PaymentMethod.digital
        ? copy.t('डिजिटल', 'Digital')
        : copy.t('नगद', 'Cash');
    return Scaffold(
      appBar: AppBar(title: Text(copy.t('बिल विवरण', 'Entry details'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 1,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  right: -34,
                  bottom: -42,
                  child: Icon(
                    bill.paymentMethod == PaymentMethod.digital
                        ? Icons.qr_code_2
                        : Icons.receipt_long,
                    size: 190,
                    color: accent.withValues(alpha: .07),
                  ),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: .14),
                        Theme.of(context).colorScheme.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  active ? Icons.check_circle : Icons.info,
                                  size: 16,
                                  color: accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            bill.paymentMethod == PaymentMethod.digital
                                ? Icons.qr_code
                                : Icons.payments_outlined,
                            color: accent,
                          ),
                          const SizedBox(width: 7),
                          Text(paymentLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        bill.coupon == null
                            ? copy.t('बिल नम्बर', 'Bill number')
                            : copy.t('कुपन कोड', 'Coupon code'),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 5),
                      SelectableText(
                        bill.coupon ?? bill.billNumber,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: bill.coupon == null ? 0 : 1.1,
                                ),
                      ),
                      if (bill.coupon != null) ...[
                        const SizedBox(height: 8),
                        Text('${copy.t('बिल', 'Bill')}: ${bill.billNumber}'),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 20,
                        runSpacing: 10,
                        children: [
                          _HeaderFact(
                            icon: Icons.currency_rupee,
                            value: bill.amount.toStringAsFixed(2),
                            accent: accent,
                          ),
                          _HeaderFact(
                            icon: Icons.calendar_today_outlined,
                            value: bill.billDate
                                .toIso8601String()
                                .substring(0, 10),
                            accent: accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.image_outlined, color: accent),
                      const SizedBox(width: 9),
                      Text(copy.t('बिलको फोटो', 'Bill photo'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text(copy.t('जुम गर्न थिच्नुहोस्', 'Pinch to zoom'),
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Image.file(
                        File(bill.imagePath),
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image, size: 64)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.receipt_long_outlined, color: accent),
                    const SizedBox(width: 9),
                    Text(copy.t('खरिद विवरण', 'Purchase details'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  _DetailRow(
                      icon: Icons.tag,
                      label: copy.t('बिल नम्बर', 'Bill number'),
                      value: bill.billNumber,
                      accent: accent),
                  _DetailRow(
                      icon: Icons.storefront_outlined,
                      label: copy.t('विक्रेता PAN/VAT', 'Seller PAN/VAT'),
                      value: bill.sellerPan,
                      accent: accent),
                  _DetailRow(
                      icon: Icons.calendar_month_outlined,
                      label: copy.t('बिल मिति', 'Bill date'),
                      value: bill.billDate.toIso8601String().substring(0, 10),
                      accent: accent),
                  _DetailRow(
                      icon: Icons.currency_rupee,
                      label: copy.t('जम्मा रकम', 'Total amount'),
                      value: 'Rs ${bill.amount.toStringAsFixed(2)}',
                      accent: accent),
                  _DetailRow(
                      icon: bill.paymentMethod == PaymentMethod.digital
                          ? Icons.qr_code
                          : Icons.payments_outlined,
                      label: copy.t('भुक्तानी', 'Payment'),
                      value: paymentLabel,
                      accent: accent),
                  _DetailRow(
                      icon: Icons.schedule,
                      label: copy.t('सुरक्षित गरिएको', 'Saved'),
                      value:
                          bill.createdAt.toLocal().toString().substring(0, 16),
                      accent: accent,
                      showDivider: false),
                ],
              ),
            ),
          ),
          if (bill.serverMessage?.trim().isNotEmpty == true)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: accent),
                    const SizedBox(width: 12),
                    Expanded(child: Text(bill.serverMessage!)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderFact extends StatelessWidget {
  const _HeaderFact(
      {required this.icon, required this.value, required this.accent});

  final IconData icon;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 2),
                      SelectableText(value,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showDivider) const Divider(height: 1, indent: 50),
        ],
      );
}

class WinnersPage extends StatelessWidget {
  const WinnersPage(
      {super.key, required this.language, required this.firebase});
  final AppLanguage language;
  final FirebaseService firebase;

  @override
  Widget build(BuildContext context) {
    final copy = Copy(language);
    return FutureBuilder<List<Map<String, String>>>(
        future: firebase.getWinners(),
        builder: (context, snapshot) =>
            ListView(padding: const EdgeInsets.all(20), children: [
              const Icon(Icons.emoji_events, size: 72, color: Colors.amber),
              const SizedBox(height: 12),
              Text(copy.t('आधिकारिक विजेता', 'Official winners'),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                  copy.t(
                      'तपाईंको सुरक्षित कुपन विजेता सूचीमा भेटिएमा यस उपकरणमा सूचना आउनेछ।',
                      'This device will be notified when one of its saved coupons appears in the winners list.'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasData && snapshot.data!.isNotEmpty)
                ...snapshot.data!.map((winner) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.emoji_events_outlined),
                        title: Text(winner['coupon'] ?? ''),
                        subtitle: Text([winner['category'], winner['drawDate']]
                            .where((value) => value?.isNotEmpty == true)
                            .join(' • ')),
                        trailing: Text(winner['prizeAmount']?.isNotEmpty == true
                            ? 'Rs ${winner['prizeAmount']}'
                            : ''),
                      ),
                    )),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                  onPressed: () => launchUrl(Uri.parse(firebase.portalUrl),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(copy.t('आधिकारिक पोर्टल खोल्नुहोस्',
                      'Open official IRD portal'))),
              const SizedBox(height: 18),
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(copy.t(
                          'विजेता घोषणा भएको १५ दिनभित्र आवश्यक कागजातसहित पुरस्कार दाबी गर्नुहोस्।',
                          'A winner must claim the prize with the required documents within 15 days of announcement.')))),
            ]));
  }
}
