# Vendo Mobile

Flutter applications for Vendo live in `vendo_rider/` and `vendo_buyer/`. This repository has its own [working rules](AGENTS.md) and [documentation](docs/README.md). The Laravel marketplace and logistics backend lives separately in `../E-Comm_Web`.

The rider app now has a live integration path for verified registration, approved-rider password/Google login, email-code password recovery, assigned work, and scan transitions supported by the web API. Google Sign-In needs Google Cloud Android/iOS/macOS OAuth setup and does not run on Linux desktop. Linux webcam scanning needs the system `zbar` package; Android/iOS use the Flutter scanner. See the [rider integration spec](docs/features/rider-integration.md) for behavior, configuration, and remaining gaps. The buyer app is separate work.
