all: supply_chain_ledger compliance_mapper

supply_chain_ledger:
    go build -o build/supply_chain_ledger src/supply_chain_ledger.go

compliance_mapper:
    javac src/compliance_mapper.java -d build/
