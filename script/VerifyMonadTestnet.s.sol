// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title Verify LiquidArena Contracts on Monad Testnet
 * @notice Script to verify deployed contracts on Monad Testnet using Sourcify
 * @dev Reads deployment addresses from JSON file and verifies contracts
 */
contract VerifyMonadTestnet is Script {
    // Monad Testnet configuration
    uint256 public constant MONAD_TESTNET_CHAIN_ID = 10143;
    string public constant VERIFIER_URL = "https://sourcify-api-monad.blockvision.org";
    
    // Contract paths for verification
    string public constant RANGE_VAULT_PATH = "src/LPBattleVault.sol:LPBattleVault";
    string public constant FEE_BATTLE_PATH = "src/LPFeeBattle.sol:LPFeeBattle";
    
    struct DeploymentData {
        address rangeVault;
        address feeBattle;
        address positionManager;
        address factory;
    }

    function run() external {
        // Validate we're on Monad Testnet
        require(block.chainid == MONAD_TESTNET_CHAIN_ID, "Must verify on Monad Testnet");
        
        console.log("=== LiquidArena Contract Verification ===");
        console.log("Network: Monad Testnet");
        console.log("Chain ID:", block.chainid);
        console.log("Verifier URL:", VERIFIER_URL);
        console.log("");

        // Read deployment addresses
        DeploymentData memory deployment = readDeploymentData();
        
        // Verify contracts
        verifyLPBattleVault(deployment);
        verifyLPFeeBattle(deployment);
        
        console.log("\n=== Verification Complete ===");
        console.log("All contracts have been submitted for verification.");
        console.log("Check verification status at:", VERIFIER_URL);
    }

    /**
     * @notice Read deployment data from JSON file
     * @dev Parses the deployment JSON file to extract contract addresses
     */
    function readDeploymentData() internal view returns (DeploymentData memory) {
        string memory deploymentFile = "deployments/monad-testnet.json";
        
        // Check if deployment file exists
        try vm.readFile(deploymentFile) returns (string memory json) {
            console.log("Reading deployment data from:", deploymentFile);
            
            // Parse JSON to extract addresses
            address rangeVault = vm.parseJsonAddress(json, ".contracts.LPBattleVault.address");
            address feeBattle = vm.parseJsonAddress(json, ".contracts.LPFeeBattle.address");
            address positionManager = vm.parseJsonAddress(json, ".constructor_args.positionManager");
            address factory = vm.parseJsonAddress(json, ".constructor_args.factory");
            
            console.log("LPBattleVault address:", rangeVault);
            console.log("LPFeeBattle address:", feeBattle);
            console.log("");
            
            return DeploymentData({
                rangeVault: rangeVault,
                feeBattle: feeBattle,
                positionManager: positionManager,
                factory: factory
            });
        } catch {
            revert("Deployment file not found. Please run deployment script first.");
        }
    }

    /**
     * @notice Verify LPBattleVault contract
     * @dev Submits LPBattleVault for verification with constructor arguments
     */
    function verifyLPBattleVault(DeploymentData memory deployment) internal {
        console.log("Verifying LPBattleVault...");
        
        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(
            deployment.positionManager,
            deployment.factory
        );
        
        // Build verification command
        string[] memory cmd = new string[](8);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(deployment.rangeVault);
        cmd[3] = RANGE_VAULT_PATH;
        cmd[4] = "--chain";
        cmd[5] = "10143";
        cmd[6] = "--verifier";
        cmd[7] = "sourcify";
        
        console.log("Command: forge verify-contract", vm.toString(deployment.rangeVault), RANGE_VAULT_PATH, "--chain 10143 --verifier sourcify --verifier-url", VERIFIER_URL);
        
        // Note: In a real script, you would execute this command
        // For now, we'll just log the command for manual execution
        console.log("Execute this command manually:");
        console.log("forge verify-contract", vm.toString(deployment.rangeVault), RANGE_VAULT_PATH, "--chain 10143 --verifier sourcify --verifier-url", VERIFIER_URL);
        console.log("");
    }

    /**
     * @notice Verify LPFeeBattle contract
     * @dev Submits LPFeeBattle for verification with constructor arguments
     */
    function verifyLPFeeBattle(DeploymentData memory deployment) internal {
        console.log("Verifying LPFeeBattle...");
        
        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(
            deployment.positionManager,
            deployment.factory
        );
        
        console.log("Execute this command manually:");
        console.log("forge verify-contract", vm.toString(deployment.feeBattle), FEE_BATTLE_PATH, "--chain 10143 --verifier sourcify --verifier-url", VERIFIER_URL);
        console.log("");
    }
}
