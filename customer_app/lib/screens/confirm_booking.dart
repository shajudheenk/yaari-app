import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:yaari_ui/yaari_ui.dart';

import '../booking.dart';
import '../data.dart';
import '../geocode.dart';
import '../place.dart';
import '../plan.dart';
import 'booking_status.dart';

/// Review and confirm.
///
/// Built as a review screen rather than a form. Every decision — where, when,
/// how often, how you pay — is a row showing its current answer, and tapping
/// it opens a sheet to change that one thing. It is how checkout works in
/// every app people already know, and it means nothing is ever more than one
/// tap from being corrected.
class ConfirmBookingScreen extends StatefulWidget {
  const ConfirmBookingScreen({
    super.key,
    required this.trade,
    required this.service,
    required this.provider,
    required this.place,
  });

  final Trade trade;
  final Service service;
  final NearbyProvider provider;
  final Place place;

  @override
  State<ConfirmBookingScreen> createState() => _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends State<ConfirmBookingScreen> {
  late Future<List<Address>> _addresses;
  Address? _address;
  PayBy _payBy = PayBy.cash;
  bool _asap = true;
  DateTime? _slot;
  bool _busy = false;
  String? _error;

  /// Null means a single visit. Anything else sets up a standing arrangement
  /// at a rate below the one-off price.
  PlanFrequency? _repeat;

  /// Read from the database rather than written into the app, so the offer
  /// can change without a release.
  int _discountBps = 0;

  /// How this service is sold. Empty for most — one flat price — and a list
  /// of property sizes or room types for the ones that need it.
  List<ServiceOption> _options = const [];
  ServiceOption? _option;
  int _qty = 1;
  bool _optionsLoading = true;

  @override
  void initState() {
    super.initState();
    _addresses = BookingApi.myAddresses();
    _preselectAddress();
    _loadDiscount();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final list = await Api.optionsFor(widget.service.id);
      if (!mounted) return;
      setState(() {
        _options = list;
        // Preselecting the first option means the price shown is always a
        // real price. Leaving it null would show the headline "from" figure
        // and then change it at the last step, which is the oldest trick in
        // the book and not one we are doing.
        _option = list.isEmpty ? null : list.first;
        _qty = _option?.minQty ?? 1;
        _optionsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _optionsLoading = false);
    }
  }

  Future<void> _preselectAddress() async {
    try {
      final list = await _addresses;
      if (mounted && list.isNotEmpty && _address == null) {
        setState(() => _address = list.first);
      }
    } catch (_) {/* the row simply shows "Choose" */}
  }

  Future<void> _loadDiscount() async {
    try {
      final bps = await PlanApi.discountBps();
      if (mounted) setState(() => _discountBps = bps);
    } catch (_) {/* repeat options still work, at the full rate */}
  }

  /// What the chosen option costs, before any repeat discount. Mirrors
  /// quote_service() on the server, which is what actually decides the price.
  ///
  /// Includes the professional's tier: a Gold pro costs more than a Bronze
  /// one for the same job, and the server applies the same uplift.
  int get _basePence => widget.provider
      .priceFor(_option?.priceFor(_qty) ?? widget.service.ratePence);

  int get _pricePence => _repeat == null
      ? _basePence
      : PlanApi.planRate(_basePence, _discountBps);

  /// A service sold by option cannot be booked until one is chosen.
  bool get _optionReady => _options.isEmpty || _option != null;

  bool get _ready =>
      _address != null &&
      _optionReady &&
      !_optionsLoading &&
      (_repeat == null ? (_asap || _slot != null) : _slot != null);

  /// "3 bedrooms" or "5 × Bedrooms" — what the customer picked, in the words
  /// they picked it in.
  String? get _optionLabel {
    final o = _option;
    if (o == null) return null;
    return o.isCountable ? '$_qty × ${o.label}' : o.label;
  }

  Future<void> _pickOption() async {
    if (_options.isEmpty) return;
    final res = await showYaariSheet<(ServiceOption, int)>(
      context,
      expand: _options.length > 4,
      child: _OptionSheet(
        options: _options,
        current: _option,
        quantity: _qty,
        serviceName: widget.service.name,
        colour: categoryOf(widget.trade.slug).base,
        // The sheet shows this professional's prices, tier included, so the
        // number tapped is the number charged.
        price: widget.provider.priceFor,
      ),
    );
    if (res != null && mounted) {
      setState(() {
        _option = res.$1;
        _qty = res.$2;
      });
    }
  }

  Future<void> _pickAddress() async {
    final picked = await showYaariSheet<Address>(
      context,
      expand: true,
      child: _AddressSheet(current: _address, place: widget.place),
    );
    if (picked != null && mounted) {
      setState(() => _address = picked);
      _addresses = BookingApi.myAddresses();
    }
  }

  Future<void> _pickWhen() async {
    final res = await showYaariSheet<(bool, DateTime?)>(
      context,
      expand: true,
      child: _WhenSheet(
        asap: _asap,
        slot: _slot,
        // A repeating arrangement needs a first date to repeat from, so
        // "as soon as someone is free" is not a valid answer to "when".
        allowAsap: _repeat == null,
        colour: categoryOf(widget.trade.slug).base,
      ),
    );
    if (res != null && mounted) {
      setState(() {
        _asap = res.$1;
        _slot = res.$2;
      });
    }
  }

  Future<void> _pickRepeat() async {
    final res = await showYaariSheet<PlanFrequency?>(
      context,
      child: _RepeatSheet(
        current: _repeat,
        basePence: widget.service.ratePence,
        discountBps: _discountBps,
        unit: widget.service.rateUnit,
        colour: categoryOf(widget.trade.slug).base,
      ),
    );
    if (!mounted) return;
    // A sheet dismissed by swiping returns null, which must not be read as
    // "they chose one-off" — only an explicit tap changes the answer.
    if (res == null && _repeat == null) return;
    setState(() {
      _repeat = res;
      if (res != null && _asap) {
        _asap = false;
        _slot = null;
      }
    });
  }

  Future<void> _pickPayment() async {
    final res = await showYaariSheet<PayBy>(
      context,
      child: _PaymentSheet(current: _payBy),
    );
    if (res != null && mounted) setState(() => _payBy = res);
  }

  Future<void> _confirm() async {
    final addr = _address;
    if (addr == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final repeat = _repeat;
      final created = repeat == null
          ? await BookingApi.create(
              serviceId: widget.service.id,
              addressId: addr.id,
              providerId: widget.provider.userId,
              asap: _asap,
              scheduledFor: _asap ? null : _slot,
              optionId: _option?.id,
              quantity: _qty,
            )
          : (await PlanApi.create(
              serviceId: widget.service.id,
              addressId: addr.id,
              providerId: widget.provider.userId,
              frequency: repeat,
              firstAt: _slot!,
              optionId: _option?.id,
              quantity: _qty,
            ))
              .$2;

      if (_payBy == PayBy.card) {
        await BookingApi.setPaymentMethod(created.id, PayBy.card);
      }

      if (!mounted) return;
      Buzz.commit();
      Navigator.of(context).pushReplacement(
        YaariPage(
          builder: (_) => BookingStatusScreen(
              bookingId: created.id, justCreated: created),
        ),
      );
    } catch (e) {
      if (mounted) {
        Buzz.reject();
        setState(() {
          _error = _humanise(e);
          _busy = false;
        });
      }
    }
  }

  /// Database errors are precise but not friendly. Keep the meaning, lose the
  /// jargon — and always say what to do next.
  String _humanise(Object e) {
    final s = e.toString();
    if (s.contains('no longer available')) {
      return '${widget.provider.name.split(' ').first} has just gone offline, '
          'or their credentials lapsed. Please choose someone else.';
    }
    if (s.contains('address is not yours')) {
      return 'That address could not be used. Try picking it again.';
    }
    if (s.contains('first visit has to be in the future')) {
      return 'Pick a time that has not already passed.';
    }
    if (s.contains('within the next three months')) {
      return 'A repeat plan has to start within the next three months.';
    }
    if (s.contains('not available')) return 'That service is no longer listed.';
    return 'Could not create the booking. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(widget.trade.slug);

    return Scaffold(
      backgroundColor: Surface.canvas,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Pressable(
            onTap: () => Navigator.of(context).maybePop(),
            scale: 0.9,
            child: Container(
              decoration: BoxDecoration(
                  color: Surface.raised,
                  shape: BoxShape.circle,
                  boxShadow: Shade.sm),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 20, color: Coal.c900),
            ),
          ),
        ),
        title: const Text('Review'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.huge),
        children: [
          Steps(step: 4, of: 4, label: 'Confirm and request', colour: c.base),
          const SizedBox(height: Gap.xl),

          Reveal(child: _JobCard(
              trade: widget.trade, service: widget.service, pro: widget.provider)),
          const SizedBox(height: Gap.lg),

          Reveal(
            delay: const Duration(milliseconds: 60),
            child: Panel(
              padding: EdgeInsets.zero,
              shadow: Shade.sm,
              child: Column(children: [
                if (_optionsLoading || _options.isNotEmpty) ...[
                  _Choice(
                    icon: Icons.straighten_rounded,
                    label: _options.any((o) => o.rateUnit == 'room')
                        ? 'Rooms'
                        : 'Size',
                    value: _optionsLoading ? 'Loading…' : _optionLabel,
                    placeholder: 'Choose',
                    colour: c.base,
                    onTap: _optionsLoading ? null : _pickOption,
                  ),
                  const Divider(height: 1, indent: 56),
                ],
                _Choice(
                  icon: Icons.place_rounded,
                  label: 'Address',
                  value: _address?.oneLine,
                  placeholder: 'Choose where',
                  colour: c.base,
                  onTap: _pickAddress,
                ),
                const Divider(height: 1, indent: 56),
                _Choice(
                  icon: Icons.schedule_rounded,
                  label: 'When',
                  value: _repeat == null && _asap
                      ? 'As soon as someone is free'
                      : _slot == null
                          ? null
                          : _formatSlot(_slot!),
                  placeholder: 'Pick a time',
                  colour: c.base,
                  onTap: _pickWhen,
                ),
                const Divider(height: 1, indent: 56),
                _Choice(
                  icon: Icons.event_repeat_rounded,
                  label: 'How often',
                  value: _repeat?.label ?? 'Just this once',
                  placeholder: 'Choose',
                  colour: c.base,
                  badge: _repeat == null && _discountBps > 0
                      ? 'Save ${(_discountBps / 100).round()}%'
                      : null,
                  onTap: _pickRepeat,
                ),
                const Divider(height: 1, indent: 56),
                _Choice(
                  icon: _payBy == PayBy.cash
                      ? Icons.payments_rounded
                      : Icons.credit_card_rounded,
                  label: 'Payment',
                  value: _payBy == PayBy.cash
                      ? 'Cash or card on the day'
                      : 'Card, held until the job is done',
                  placeholder: 'Choose',
                  colour: c.base,
                  onTap: _pickPayment,
                ),
              ]),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: Gap.lg),
            _ErrorCard(message: _error!),
          ],

          const SizedBox(height: Gap.lg),
          Reveal(
            delay: const Duration(milliseconds: 120),
            child: _Protections(colour: c.deep),
          ),
        ],
      ),
      bottomNavigationBar: PriceBar(
        caption: _repeat != null
            ? '${_repeat!.label}, per visit'
            : widget.service.rateUnit == 'hour'
                ? 'Estimated, first hour'
                : 'Fixed price, all in',
        price: formatPence(_pricePence),
        wasPrice: _repeat != null && widget.service.ratePence > _pricePence
            ? formatPence(widget.service.ratePence)
            : null,
        action: _repeat != null ? 'Start plan' : 'Request booking',
        colour: c.base,
        busy: _busy,
        note: _repeat != null
            ? 'No contract. Pause or stop whenever you like.'
            : 'Free to cancel any time before work starts',
        onAction: _ready && !_busy ? _confirm : null,
      ),
    );
  }

  static String _formatSlot(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    if (isToday) return 'Today at $hh:$mm';
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}, $hh:$mm';
  }
}

/// What is being booked, and with whom — restated so the last screen before
/// committing never requires scrolling back to check.
class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.trade,
    required this.service,
    required this.pro,
  });

  final Trade trade;
  final Service service;
  final NearbyProvider pro;

  @override
  Widget build(BuildContext context) {
    final c = categoryOf(trade.slug);

    return Panel(
      padding: const EdgeInsets.all(Gap.lg),
      shadow: Shade.md,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: c.tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: YaariMark(trade.slug, size: 30, ink: c.deep, accent: c.base),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Txt.cardTitle.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Avatar(pro.name, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('with ${pro.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Txt.meta),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A decision row: what it is, what it currently says, one tap to change it.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.colour,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final Color colour;

  /// Null while the row has nothing to offer yet — the options are still
  /// loading. The row stays visible so the list does not jump.
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final set = value != null;

    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg, vertical: Gap.lg),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: colour),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: Txt.label),
                      if (badge != null) ...[
                        const SizedBox(width: Gap.sm),
                        Pill(badge!, tone: ChipTone.success, dense: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Txt.cardTitle.copyWith(
                      fontSize: 14,
                      color: set ? Coal.c900 : Coal.c400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Coal.c400),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Panel(
      colour: Signal.dangerSoft,
      shadow: const [],
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: Signal.danger),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(message,
                style: Txt.body.copyWith(
                    color: const Color(0xFF8C2A1F), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Protections extends StatelessWidget {
  const _Protections({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) {
    const lines = [
      (Icons.lock_clock_rounded, 'Nothing is charged until the job is done'),
      (Icons.pin_rounded, 'Only your four digit code can close it'),
      (Icons.event_busy_rounded, 'Cancel free any time before work starts'),
    ];

    return Column(
      children: [
        for (final (icon, text) in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Row(
              children: [
                Icon(icon, size: 15, color: colour),
                const SizedBox(width: Gap.md),
                Expanded(child: Text(text, style: Txt.meta)),
              ],
            ),
          ),
      ],
    );
  }
}

// ============================================================ sheets

/// Pick a saved address, or add one.
class _AddressSheet extends StatefulWidget {
  const _AddressSheet({required this.current, required this.place});

  final Address? current;
  final Place place;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late Future<List<Address>> _list;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _list = BookingApi.myAddresses();
  }

  @override
  Widget build(BuildContext context) {
    if (_adding) {
      return _AddAddress(
        place: widget.place,
        onAdded: (a) => Navigator.of(context).pop(a),
        onCancel: () => setState(() => _adding = false),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHead(
            title: 'Where is the job?',
            subtitle: 'Your full address is shared only once someone accepts'),
        Flexible(
          child: FutureBuilder<List<Address>>(
            future: _list,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(Gap.xl),
                  child: Column(children: [
                    Skeleton(height: 66, radius: Radii.card),
                    SizedBox(height: Gap.md),
                    Skeleton(height: 66, radius: Radii.card),
                  ]),
                );
              }
              final list = snap.data ?? [];
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                    Gap.xl, 0, Gap.xl, Gap.xl),
                children: [
                  for (final a in list) ...[
                    _AddressRow(
                      address: a,
                      selected: a.id == widget.current?.id,
                      onTap: () => Navigator.of(context).pop(a),
                    ),
                    const SizedBox(height: Gap.md),
                  ],
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.lg),
                      child: Text(
                        'No saved addresses yet.',
                        style: Txt.bodySm,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Btn('Add an address',
                      icon: Icons.add_rounded,
                      kind: BtnKind.secondary,
                      onTap: () => setState(() => _adding = true)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      shadow: selected ? Shade.tinted(Brand.c500) : Shade.sm,
      border: Border.all(
          color: selected ? Brand.c500 : Colors.transparent, width: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? Brand.c50 : Coal.c50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.home_rounded,
                size: 16, color: selected ? Brand.c600 : Coal.c500),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address.label,
                    style: Txt.cardTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(address.oneLine,
                    maxLines: 2, style: Txt.meta),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded,
                size: 20, color: Brand.c500),
        ],
      ),
    );
  }
}

/// Adding an address: street, postcode, and a map pin to drop it exactly.
class _AddAddress extends StatefulWidget {
  const _AddAddress({
    required this.place,
    required this.onAdded,
    required this.onCancel,
  });

  final Place place;
  final ValueChanged<Address> onAdded;
  final VoidCallback onCancel;

  @override
  State<_AddAddress> createState() => _AddAddressState();
}

class _AddAddressState extends State<_AddAddress> {
  final _line1 = TextEditingController();
  final _postcode = TextEditingController();
  Timer? _debounce;
  PostcodePlace? _found;
  ServiceArea? _covered;
  LatLng? _pin;
  bool _looking = false;
  bool _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _postcode.addListener(_onPostcodeChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _postcode.removeListener(_onPostcodeChanged);
    _line1.dispose();
    _postcode.dispose();
    super.dispose();
  }

  void _onPostcodeChanged() {
    // Wait for a pause in typing rather than firing a lookup per keystroke.
    _debounce?.cancel();
    final text = _postcode.text;
    if (text.replaceAll(' ', '').length < 5) {
      if (_found != null) {
        setState(() {
          _found = null;
          _covered = null;
          _pin = null;
          _note = null;
        });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _lookup(text));
  }

  Future<void> _lookup(String text) async {
    setState(() {
      _looking = true;
      _note = null;
    });
    try {
      final place = await Geocode.lookup(text);

      // Coverage is a database question, not a list of city names held in
      // the app: where we can serve depends on where there is supply, and
      // that changes without a release.
      final covered =
          place == null ? null : await Api.coveredArea(place.lat, place.lng);

      if (!mounted) return;
      setState(() {
        _found = place;
        _covered = covered;
        _pin = place == null ? null : LatLng(place.lat, place.lng);
        _note = place == null
            ? 'That is not a UK postcode we recognise.'
            : covered != null
                ? null
                : 'We are not in ${place.district ?? "that area"} yet. You '
                    'can still save it, but nobody will be available there '
                    'until we open.';
        _looking = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _looking = false;
          _note = 'Could not check that postcode. You can still save it.';
        });
      }
    }
  }

  bool get _canSave =>
      _line1.text.trim().isNotEmpty && _found != null && !_busy;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _busy = true);
    try {
      final a = await BookingApi.addAddress(
        label: 'Home',
        line1: _line1.text.trim(),
        postcode: _found!.postcode,
        lat: _pin?.latitude,
        lng: _pin?.longitude,
        city: _covered?.city ?? _found!.district,
      );
      widget.onAdded(a);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _note = 'Could not save that address. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHead(
            title: 'Add an address',
            subtitle: 'Drag the pin if it lands in the wrong spot'),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
            children: [
              TextField(
                controller: _line1,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'House number and street',
                  hintText: '14 Bristol Road',
                ),
              ),
              const SizedBox(height: Gap.md),
              TextField(
                controller: _postcode,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Postcode',
                  hintText: 'B29 6BD',
                  suffixIcon: _looking
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _found != null
                          ? const Icon(Icons.check_circle_rounded,
                              color: Signal.success, size: 20)
                          : null,
                ),
              ),
              if (_note != null) ...[
                const SizedBox(height: Gap.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 15, color: Signal.warning),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(_note!,
                          style:
                              Txt.meta.copyWith(color: Signal.warning)),
                    ),
                  ],
                ),
              ],
              if (_pin != null) ...[
                const SizedBox(height: Gap.lg),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.card),
                  child: YaariMap(
                    centre: _pin!,
                    height: 170,
                    onMoved: (p) => _pin = p,
                  ),
                ),
              ],
              const SizedBox(height: Gap.xl),
              Btn('Save address',
                  onTap: _canSave ? _save : null, busy: _busy),
              const SizedBox(height: Gap.sm),
              Btn('Back', kind: BtnKind.ghost, onTap: widget.onCancel),
            ],
          ),
        ),
      ],
    );
  }
}

/// When. As soon as possible, or a specific slot in the next fortnight.
class _WhenSheet extends StatefulWidget {
  const _WhenSheet({
    required this.asap,
    required this.slot,
    required this.allowAsap,
    required this.colour,
  });

  final bool asap;
  final DateTime? slot;
  final bool allowAsap;
  final Color colour;

  @override
  State<_WhenSheet> createState() => _WhenSheetState();
}

class _WhenSheetState extends State<_WhenSheet> {
  late bool _asap = widget.asap && widget.allowAsap;
  late DateTime _day = widget.slot ?? DateTime.now();
  late DateTime? _slot = widget.slot;

  /// Half-hour slots across the working day. Anything already in the past is
  /// offered but disabled, so the grid does not reflow as the day goes on.
  List<DateTime> get _slotsForDay {
    final out = <DateTime>[];
    for (var h = 8; h <= 19; h++) {
      for (final m in [0, 30]) {
        out.add(DateTime(_day.year, _day.month, _day.day, h, m));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
        14, (i) => DateTime.now().add(Duration(days: i)));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHead(
          title: 'When suits you?',
          subtitle: widget.allowAsap
              ? 'Right away, or pick a slot'
              : 'A repeat plan needs a first visit to repeat from',
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
            children: [
              if (widget.allowAsap) ...[
                Panel(
                  onTap: () => setState(() {
                    Buzz.pick();
                    _asap = true;
                    _slot = null;
                  }),
                  padding: const EdgeInsets.all(Gap.lg),
                  shadow: _asap ? Shade.tinted(widget.colour) : Shade.sm,
                  border: Border.all(
                      color: _asap ? widget.colour : Colors.transparent,
                      width: 2),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.colour.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.bolt_rounded,
                            size: 17, color: widget.colour),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('As soon as someone is free',
                                style: Txt.cardTitle.copyWith(fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('Usually within a couple of hours',
                                style: Txt.meta),
                          ],
                        ),
                      ),
                      if (_asap)
                        Icon(Icons.check_circle_rounded,
                            size: 20, color: widget.colour),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.xl),
                Row(children: [
                  Expanded(child: Container(height: 1, color: Coal.c100)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                    child: Text('OR PICK A TIME', style: Txt.label),
                  ),
                  Expanded(child: Container(height: 1, color: Coal.c100)),
                ]),
                const SizedBox(height: Gap.lg),
              ],

              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
                  itemBuilder: (context, i) => _DayChip(
                    date: days[i],
                    selected: _sameDay(days[i], _day) && !_asap,
                    colour: widget.colour,
                    onTap: () {
                      Buzz.tap();
                      setState(() {
                        _day = days[i];
                        _asap = false;
                        _slot = null;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: Gap.xl),

              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final s in _slotsForDay)
                    _SlotChip(
                      time: s,
                      // A slot in the past cannot be booked, but keeping it
                      // visible stops the grid reflowing through the day.
                      enabled: s.isAfter(
                          DateTime.now().add(const Duration(minutes: 30))),
                      selected: _slot == s,
                      colour: widget.colour,
                      onTap: () {
                        Buzz.pick();
                        setState(() {
                          _slot = s;
                          _asap = false;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: Gap.xl),
              Btn(
                'Confirm time',
                colour: widget.colour,
                onTap: (_asap || _slot != null)
                    ? () => Navigator.of(context).pop((_asap, _slot))
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.selected,
    required this.colour,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final Color colour;
  final VoidCallback onTap;

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.settle,
        width: 58,
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        decoration: BoxDecoration(
          color: selected ? colour : Surface.raised,
          borderRadius: BorderRadius.circular(Radii.button),
          boxShadow: selected ? Shade.tinted(colour) : Shade.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isToday ? 'TODAY' : _days[date.weekday - 1],
              style: Txt.label.copyWith(
                  fontSize: 8.5,
                  color: selected ? Colors.white : Coal.c500),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              style: Txt.cardTitle.copyWith(
                  fontSize: 17,
                  color: selected ? Colors.white : Coal.c900),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.time,
    required this.enabled,
    required this.selected,
    required this.colour,
    required this.onTap,
  });

  final DateTime time;
  final bool enabled;
  final bool selected;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';

    return Pressable(
      onTap: enabled ? onTap : null,
      scale: 0.92,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.settle,
        padding:
            const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colour
              : enabled
                  ? Surface.raised
                  : Coal.c50,
          borderRadius: BorderRadius.circular(Radii.chip),
          boxShadow: selected ? Shade.tinted(colour) : null,
          border: Border.all(
            color: selected ? colour : Coal.c100,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: Txt.meta.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: selected
                ? Colors.white
                : enabled
                    ? Coal.c800
                    : Coal.c300,
          ),
        ),
      ),
    );
  }
}

/// One-off, or a standing arrangement at a lower rate.
class _RepeatSheet extends StatelessWidget {
  const _RepeatSheet({
    required this.current,
    required this.basePence,
    required this.discountBps,
    required this.unit,
    required this.colour,
  });

  final PlanFrequency? current;
  final int basePence;
  final int discountBps;
  final String unit;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final planPence = PlanApi.planRate(basePence, discountBps);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHead(
          title: 'How often?',
          subtitle: discountBps > 0
              ? 'Repeat visits cost less, and you keep the same person'
              : 'Book once, or set up a regular slot',
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
            children: [
              _RepeatRow(
                title: 'Just this once',
                subtitle: 'A single visit',
                price: formatRate(basePence, unit),
                selected: current == null,
                colour: colour,
                onTap: () => Navigator.of(context).pop(null),
              ),
              const SizedBox(height: Gap.md),
              for (final f in PlanFrequency.values) ...[
                _RepeatRow(
                  title: f.label,
                  subtitle: f.blurb,
                  price: formatRate(planPence, unit),
                  wasPrice: planPence < basePence
                      ? formatRate(basePence, unit)
                      : null,
                  popular: f == PlanFrequency.weekly,
                  selected: current == f,
                  colour: colour,
                  onTap: () => Navigator.of(context).pop(f),
                ),
                const SizedBox(height: Gap.md),
              ],
              const SizedBox(height: Gap.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: Coal.c500),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      'No contract and no notice period. Pause or stop a '
                      'plan whenever you like — stopping also cancels the '
                      'visit already in the diary.',
                      style: Txt.meta,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RepeatRow extends StatelessWidget {
  const _RepeatRow({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.selected,
    required this.colour,
    required this.onTap,
    this.wasPrice,
    this.popular = false,
  });

  final String title;
  final String subtitle;
  final String price;
  final String? wasPrice;
  final bool popular;
  final bool selected;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      shadow: selected ? Shade.tinted(colour) : Shade.sm,
      border:
          Border.all(color: selected ? colour : Colors.transparent, width: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title,
                          style: Txt.cardTitle.copyWith(fontSize: 14.5)),
                    ),
                    if (popular) ...[
                      const SizedBox(width: Gap.sm),
                      const Pill('Most popular',
                          tone: ChipTone.warning, dense: true),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Txt.meta),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: Txt.price.copyWith(fontSize: 15)),
              if (wasPrice != null)
                Text(wasPrice!,
                    style: Txt.meta.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: Coal.c400)),
            ],
          ),
        ],
      ),
    );
  }
}

/// How to pay.
class _PaymentSheet extends StatelessWidget {
  const _PaymentSheet({required this.current});

  final PayBy current;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHead(
            title: 'How would you like to pay?',
            subtitle: 'Nothing is taken until the work is finished'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
          child: Column(children: [
            _PayRow(
              icon: Icons.payments_rounded,
              title: 'Cash or card on the day',
              subtitle: 'Settle directly with your professional',
              selected: current == PayBy.cash,
              onTap: () => Navigator.of(context).pop(PayBy.cash),
            ),
            const SizedBox(height: Gap.md),
            _PayRow(
              icon: Icons.credit_card_rounded,
              title: 'Card, through Yaari',
              subtitle: 'Held when you book, taken when the job is done',
              selected: current == PayBy.card,
              onTap: () => Navigator.of(context).pop(PayBy.card),
            ),
          ]),
        ),
      ],
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      shadow: selected ? Shade.tinted(Brand.c500) : Shade.sm,
      border: Border.all(
          color: selected ? Brand.c500 : Colors.transparent, width: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? Brand.c50 : Coal.c50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 17, color: selected ? Brand.c600 : Coal.c500),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Txt.cardTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: Txt.meta),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle_rounded,
                size: 20, color: Brand.c500),
        ],
      ),
    );
  }
}

/// Choose how the job is sized.
///
/// Two shapes in one sheet, because the catalogue has two. A fixed option —
/// "2 bedrooms" — is a single tap that closes the sheet. A countable one —
/// "Bedrooms, £18 each" — needs a number as well, so it reveals a stepper and
/// waits for Done.
///
/// The running total is shown against every row rather than only the selected
/// one, so the choice is made against real prices instead of by guessing
/// which size is affordable.
class _OptionSheet extends StatefulWidget {
  const _OptionSheet({
    required this.options,
    required this.current,
    required this.quantity,
    required this.serviceName,
    required this.colour,
    required this.price,
  });

  final List<ServiceOption> options;
  final ServiceOption? current;
  final int quantity;
  final String serviceName;
  final Color colour;

  /// Turns a base price into this professional's price.
  final int Function(int) price;

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  late ServiceOption? _sel = widget.current;
  late int _qty = widget.quantity;

  bool get _anyCountable => widget.options.any((o) => o.isCountable);

  void _choose(ServiceOption o) {
    Buzz.pick();
    if (!o.isCountable) {
      Navigator.of(context).pop((o, o.minQty));
      return;
    }
    setState(() {
      _sel = o;
      // Restart at the option's own minimum rather than carrying a count
      // across from a different room type, which would silently re-price.
      _qty = _sel == o && widget.current == o
          ? widget.quantity.clamp(o.minQty, o.maxQty)
          : o.minQty;
    });
  }

  void _bump(int by) {
    final o = _sel;
    if (o == null) return;
    final next = (_qty + by).clamp(o.minQty, o.maxQty);
    if (next == _qty) return;
    Buzz.pick();
    setState(() => _qty = next);
  }

  @override
  Widget build(BuildContext context) {
    final sel = _sel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHead(
          title: _anyCountable ? 'Which rooms?' : 'How big is the place?',
          subtitle: _anyCountable
              ? 'Pay for the rooms you want done'
              : 'So we send someone for long enough',
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.sm),
            children: [
              for (final o in widget.options) ...[
                _OptionRow(
                  option: o,
                  selected: sel?.id == o.id,
                  quantity: sel?.id == o.id ? _qty : o.minQty,
                  colour: widget.colour,
                  price: widget.price,
                  onTap: () => _choose(o),
                ),
                const SizedBox(height: Gap.md),
              ],
            ],
          ),
        ),
        if (sel != null && sel.isCountable)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, Gap.xl),
            child: Column(
              children: [
                Panel(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.lg, vertical: Gap.md),
                  shadow: Shade.sm,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('How many ${sel.label.toLowerCase()}?',
                                style: Txt.label),
                            const SizedBox(height: 2),
                            Text(
                              '${formatPence(widget.price(sel.ratePence))} each · '
                              'up to ${sel.maxQty}',
                              style: Txt.meta,
                            ),
                          ],
                        ),
                      ),
                      _Step(
                        icon: Icons.remove_rounded,
                        enabled: _qty > sel.minQty,
                        colour: widget.colour,
                        onTap: () => _bump(-1),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$_qty',
                          textAlign: TextAlign.center,
                          style: Txt.cardTitle.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ]),
                        ),
                      ),
                      _Step(
                        icon: Icons.add_rounded,
                        enabled: _qty < sel.maxQty,
                        colour: widget.colour,
                        onTap: () => _bump(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.lg),
                Btn(
                  'Done · ${formatPence(widget.price(sel.priceFor(_qty)))}',
                  colour: widget.colour,
                  onTap: () => Navigator.of(context).pop((sel, _qty)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.quantity,
    required this.colour,
    required this.price,
    required this.onTap,
  });

  final ServiceOption option;
  final bool selected;
  final int quantity;
  final Color colour;
  final int Function(int) price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final countable = option.isCountable;

    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      shadow: selected ? Shade.tinted(colour) : Shade.sm,
      border: Border.all(
          color: selected ? colour : Colors.transparent, width: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.label, style: Txt.cardTitle),
                if (option.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(option.detail!, style: Txt.meta),
                ],
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                countable
                    ? formatPence(price(option.ratePence))
                    : formatPence(price(option.priceFor(quantity))),
                style: Txt.price.copyWith(color: selected ? colour : Coal.c900),
              ),
              if (countable)
                Text('per ${option.rateUnit}', style: Txt.meta)
              else if (option.rateUnit == 'hour')
                const Text('per hour', style: Txt.meta),
            ],
          ),
          if (selected) ...[
            const SizedBox(width: Gap.md),
            Icon(Icons.check_circle_rounded, size: 20, color: colour),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.enabled,
    required this.colour,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: enabled ? colour.withValues(alpha: 0.12) : Coal.c100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              size: 18, color: enabled ? colour : Coal.c400),
        ),
      );
}
