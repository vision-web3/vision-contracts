JSON_PATH := out
STAKED_VISION_JSON_PATH := ${JSON_PATH}/IStakedVision.sol/IStakedVision.json
VISION_TOKEN_MIGRATOR_JSON_PATH := ${JSON_PATH}/VisionTokenMigrator.sol/VisionTokenMigrator.json

ABI_PATH := abis
STAKED_VISION_ABI_PATH := ${ABI_PATH}/staked-vision.abi
VISION_TOKEN_MIGRATOR_ABI_PATH := ${ABI_PATH}/vision-token-migrator.abi

.PHONY: build
build:
	forge build

.PHONY: clean
clean:
	@forge clean; \
	for path in "${ABI_PATH}" "${DOC_PATH}"; do \
		rm -r -f "$${path}"; \
	done

.PHONY: format
format:
	forge fmt src script test

.PHONY: lint
lint:
	npx solhint '{src,script,test}/**/*.sol'

.PHONY: test
test:
	forge test -vvv
fork-test:
	RUN_FORK=true forge test --fork-url ethereum-mainnet --match-contract  MigrationAndStakingForkTest -vvvv 

.PHONY: code
code: format lint build test

.PHONY: abis
abis: build
	@set -e; \
	mkdir -p "${ABI_PATH}"; \
	jq '.abi' "${STAKED_VISION_JSON_PATH}" > "${STAKED_VISION_ABI_PATH}"; \
	jq '.abi' "${VISION_TOKEN_MIGRATOR_JSON_PATH}" > "${VISION_TOKEN_MIGRATOR_ABI_PATH}"; \

.PHONY: abis-compact
abis-compact: build
	@set -e; \
	mkdir -p "${ABI_PATH}"; \
	jq -c '.abi' "${STAKED_VISION_JSON_PATH}" > "${STAKED_VISION_ABI_PATH}"; \
	jq -c '.abi' "${VISION_TOKEN_MIGRATOR_JSON_PATH}" > "${VISION_TOKEN_MIGRATOR_ABI_PATH}"; \

.PHONY: docs
docs:
	@forge doc

.PHONY: analyze-slither
analyze-slither:
	@docker run --platform linux/amd64 -v $$PWD:/share trailofbits/eth-security-toolbox slither /share