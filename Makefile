# Install all dependencies
install:
	forge soldeer install
	@echo "Installing npm dependencies not available on Soldeer..."
	@mkdir -p dependencies/ftso-adapters-0.0.1
	@cd /tmp && npm pack @flarenetwork/ftso-adapters@0.0.1-rc.1 --silent && \
		tar -xzf flarenetwork-ftso-adapters-0.0.1-rc.1.tgz && \
		cp -r package/contracts/* $(CURDIR)/dependencies/ftso-adapters-0.0.1/ && \
		rm -rf package flarenetwork-ftso-adapters-0.0.1-rc.1.tgz
	@mkdir -p dependencies/pyth-sdk-solidity-2.2.0
	@cd /tmp && npm pack @pythnetwork/pyth-sdk-solidity@4.3.1 --silent && \
		tar -xzf pythnetwork-pyth-sdk-solidity-4.3.1.tgz && \
		cp package/*.sol $(CURDIR)/dependencies/pyth-sdk-solidity-2.2.0/ && \
		rm -rf package pythnetwork-pyth-sdk-solidity-4.3.1.tgz
	@echo "All dependencies installed."
