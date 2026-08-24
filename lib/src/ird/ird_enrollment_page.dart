import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models.dart';

class IrdEnrollmentPage extends StatefulWidget {
  const IrdEnrollmentPage({
    super.key,
    required this.bill,
    required this.profile,
    required this.portalUrl,
  });

  final BillEntry bill;
  final UserProfile profile;
  final String portalUrl;

  @override
  State<IrdEnrollmentPage> createState() => _IrdEnrollmentPageState();
}

class _IrdEnrollmentPageState extends State<IrdEnrollmentPage> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('KarUpahar',
          onMessageReceived: _handleBridgeMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) async {
          await _installBridgeAndPrefill();
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error.description)));
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.portalUrl));
  }

  String get _bridgeScript {
    final values = <String, String>{
      'bill_number': widget.bill.billNumber,
      'seller_pan_no': widget.bill.sellerPan,
      'bill_date': widget.bill.billDate.toIso8601String().substring(0, 10),
      'billed_total_amount': widget.bill.amount.toStringAsFixed(2),
      'payment_method':
          widget.bill.paymentMethod == PaymentMethod.cash ? 'Cash' : 'Digital',
      'name': widget.profile.name,
      'address': widget.profile.address,
      'mobile_number': widget.profile.mobile,
      'company_website': '',
    };
    final encoded = jsonEncode(values);
    return '''
      (() => {
        const values = $encoded;
        const fill = () => {
          Object.entries(values).forEach(([name, value]) => {
            const element = document.querySelector(`[name="\${name}"]`);
            if (!element) return;
            const setter = Object.getOwnPropertyDescriptor(
              element instanceof HTMLSelectElement ? HTMLSelectElement.prototype : HTMLInputElement.prototype,
              'value'
            )?.set;
            if (setter) setter.call(element, value); else element.value = value;
            element.dispatchEvent(new Event('input', { bubbles: true }));
            element.dispatchEvent(new Event('change', { bubbles: true }));
          });
        };
        const revealEnrollment = (attempt = 0) => {
          const billNumber = document.querySelector('[name=bill_number]');
          if (!billNumber) {
            if (attempt < 12) {
              setTimeout(() => revealEnrollment(attempt + 1), 200);
            }
            return;
          }
          billNumber.scrollIntoView({ behavior: 'auto', block: 'center' });
          setTimeout(() => {
            const form = billNumber.closest('form');
            const submit = form?.querySelector('button[type=submit]');
            submit?.scrollIntoView({ behavior: 'smooth', block: 'center' });
          }, 1200);
        };
        fill();
        setTimeout(fill, 500);
        setTimeout(fill, 1500);
        setTimeout(() => revealEnrollment(), 250);

        if (!window.__karUpaharFetchWrapped) {
          window.__karUpaharFetchWrapped = true;
          const originalFetch = window.fetch.bind(window);
          window.fetch = async (...args) => {
            const response = await originalFetch(...args);
            const url = String(args[0]?.url || args[0] || '');
            if (url.includes('/api/v1/public/enrollments')) {
              const text = await response.clone().text();
              KarUpahar.postMessage(JSON.stringify({
                type: 'enrollment', status: response.status, ok: response.ok, body: text
              }));
            }
            return response;
          };
        }
      })();
    ''';
  }

  Future<void> _installBridgeAndPrefill() =>
      _controller.runJavaScript(_bridgeScript);

  void _handleBridgeMessage(JavaScriptMessage message) {
    try {
      final event = jsonDecode(message.message) as Map<String, dynamic>;
      if (event['type'] != 'enrollment') return;
      final body = event['body'] as String? ?? '';
      final decoded = _tryDecode(body);
      final coupon = _findString(decoded, const [
        'couponNumber',
        'prize_coupon_number',
        'coupon',
        'coupon_number',
        'coupon_no',
        'ticket_number',
      ]);
      final explicitMessage =
          _findString(decoded, const ['message', 'detail', 'error']);
      final ok = event['ok'] == true && coupon != null;
      Navigator.of(context).pop(IrdEnrollmentResult(
        success: ok,
        coupon: coupon,
        message: explicitMessage ?? (ok || body.isEmpty ? null : body),
      ));
    } catch (_) {
      Navigator.of(context).pop(const IrdEnrollmentResult(
        success: false,
        message: 'IRD returned a response that the app could not verify.',
      ));
    }
  }

  Object? _tryDecode(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  String? _findString(Object? value, List<String> keys) {
    if (value is Map) {
      for (final key in keys) {
        final found = value[key];
        if (found != null && found.toString().trim().isNotEmpty) {
          return found.toString();
        }
      }
      for (final child in value.values) {
        final found = _findString(child, keys);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findString(child, keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Official IRD submission')),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading) const LinearProgressIndicator(),
          ],
        ),
      );
}
