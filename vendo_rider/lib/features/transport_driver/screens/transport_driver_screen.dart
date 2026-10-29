import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/features/dashboard/screens/earnings_screen.dart';

class TransportDriverLoginScreen extends StatefulWidget {
  const TransportDriverLoginScreen({super.key});

  @override
  State<TransportDriverLoginScreen> createState() =>
      _TransportDriverLoginScreenState();
}

class _TransportDriverLoginScreenState
    extends State<TransportDriverLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await RiderApi.instance.transportDriverLogin(_email.text, _password.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TransportDriverTripsScreen()),
      );
    } on RiderApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reach Vendo. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFFAF7F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF412143),
          foregroundColor: Colors.white,
          title: const Text('Transport Driver'),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 44, color: Color(0xFF412143)),
                  const SizedBox(height: 12),
                  const Text('Sign in to your assigned trips',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A1B2C))),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF412143),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Transport Driver accounts must be approved by their Province Hub.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF756B78)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class TransportDriverTripsScreen extends StatefulWidget {
  const TransportDriverTripsScreen({super.key});

  @override
  State<TransportDriverTripsScreen> createState() =>
      _TransportDriverTripsScreenState();
}

class _TransportDriverTripsScreenState extends State<TransportDriverTripsScreen> {
  List<Map<String, dynamic>> _trips = [];
  String? _driver;
  String? _company;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await RiderApi.instance.transportDriverTrips();
      final driver = await RiderApi.instance.transportDriverName();
      final company = await RiderApi.instance.transportCompanyName();
      if (mounted) {
        setState(() {
          _trips = trips;
          _driver = driver;
          _company = company;
        });
      }
    } on RiderApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load assigned trips.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateTrip(Map<String, dynamic> trip, String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final response = await RiderApi.instance.updateTransportTrip(
        trip['id'] as int,
        action,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message']?.toString() ?? 'Trip updated.')),
      );
      await _refresh();
    } on RiderApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        if (error.statusCode == 409) await _refresh();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip update failed. Retry when connected.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    try {
      await RiderApi.instance.logoutTransportDriver();
      if (mounted) Navigator.pop(context);
    } on RiderApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xFFFAF7F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFF412143),
            foregroundColor: Colors.white,
            title: const Text('Assigned Trips'),
            actions: [
              IconButton(
                  tooltip: 'Earnings',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const EarningsScreen(transportDriver: true),
                  )),
                  icon: const Icon(Icons.account_balance_wallet_outlined)),
              IconButton(
                  tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh)),
              IconButton(
                  tooltip: 'Log out', onPressed: _logout, icon: const Icon(Icons.logout)),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(onPressed: _refresh, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(_driver == null ? 'Transport Driver' : 'Hello, $_driver',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF412143))),
                          if (_company != null)
                            Text(_company!, style: const TextStyle(color: Color(0xFF756B78))),
                          const SizedBox(height: 14),
                          if (_trips.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(22),
                                child: Text('No active trips are assigned to you yet.'),
                              ),
                            ),
                          ..._trips.map(_tripCard),
                        ],
                      ),
                    ),
        ),
      );

  Widget _tripCard(Map<String, dynamic> trip) {
    final origin = trip['origin'] is Map ? Map<String, dynamic>.from(trip['origin'] as Map) : {};
    final destination = trip['destination'] is Map ? Map<String, dynamic>.from(trip['destination'] as Map) : {};
    final vehicle = trip['vehicle'] is Map ? Map<String, dynamic>.from(trip['vehicle'] as Map) : {};
    final manifest = trip['manifest'] is List ? trip['manifest'] as List<dynamic> : const [];
    final status = trip['status']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('${trip['code'] ?? 'Trip'} · ${trip['type'] ?? 'linehaul'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              Text(status?.replaceAll('_', ' ') ?? '',
                  style: const TextStyle(color: Color(0xFF815488), fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            Text('${origin['name'] ?? 'Origin'} → ${destination['name'] ?? 'Destination'}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${origin['municipality'] ?? ''} → ${destination['municipality'] ?? ''}',
                style: const TextStyle(color: Color(0xFF756B78))),
            if (vehicle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${vehicle['type'] ?? 'Vehicle'} · ${vehicle['plate_number'] ?? vehicle['code'] ?? ''}'),
              ),
            const Divider(height: 24),
            Text('Manifest · ${manifest.length} parcels',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            ...manifest.map((parcel) {
              final row = Map<String, dynamic>.from(parcel as Map);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('${row['tracking_number'] ?? row['order_number'] ?? 'Parcel'} · ${row['status'] ?? ''}'),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _updateTrip(trip, status == 'scheduled' ? 'depart' : 'arrive'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF412143)),
                icon: Icon(status == 'scheduled' ? Icons.local_shipping_outlined : Icons.place_outlined),
                label: Text(status == 'scheduled' ? 'Depart trip' : 'Confirm arrival'),
              ),
            ),
            const Text(
              'Departure and arrival are accepted only after each parcel has its required station scan.',
              style: TextStyle(fontSize: 12, color: Color(0xFF756B78)),
            ),
          ],
        ),
      ),
    );
  }
}
