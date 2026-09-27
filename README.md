# Vendo Mobile

Flutter applications for Vendo live in `vendo_rider/` and `vendo_buyer/`. This repository has its own [working rules](AGENTS.md) and [documentation](docs/README.md). The Laravel marketplace and logistics backend lives separately in `../E-Comm_Web`.

The rider app now has a live integration path for registration, approved-rider login, assigned work, and seven scan transitions supported by the current web API, including a delivered scan after handover. Linux webcam scanning needs the system `zbar` package; Android/iOS use the Flutter scanner. See the [rider integration spec](docs/features/rider-integration.md) for the exact behavior, configuration, and remaining gaps. The buyer app is separate work.
