all: privacy_analyzer ip_monitor secure_enclave_api dependency_tracker

privacy_analyzer:
    swiftc src/privacy_analyzer.swift -o build/privacy_analyzer

ip_monitor:
    swiftc src/ip_monitor.swift -o build/ip_monitor

secure_enclave_api:
    clang++ src/secure_enclave_api.cpp -o build/secure_enclave_api

dependency_tracker:
    clang++ src/dependency_tracker.cpp -o build/dependency_tracker
