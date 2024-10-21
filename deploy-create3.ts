import { $, file, write } from "bun";

throw new Error("TODO - implement the deployment script for CREATE3Factory");




type IDeploymentMetadata = {
  [contractName: string]: string;
};

// Retrieve the network argument from the command line
const network = process.argv[2];

if (!network) {
  console.error("Please provide a network as an argument.");
  process.exit(1);
}

const scriptName = "Deploy";
const scriptFile = `${scriptName}.s.sol`;

// Run the forge script command
const result = await $`forge script script/${scriptFile} -f ${network} -vvvv --json --silent --broadcast --verify --skip-simulation`;
const stdout = result.stdout;

// Parse the JSON output
let output;
try {
  output = JSON.parse(stdout);
} catch (e) {
  console.error("Error parsing JSON output:", e);
}


const deploymentsFilePath = `./deployments/${network}.json`;
const deploymentsFile = file(deploymentsFilePath);

let deployments: IDeploymentMetadata = {};

// Check if the deployments file exists
if (await deploymentsFile.exists()) {
  try {
    deployments = await deploymentsFile.json();
  } catch (e) {
    console.error("Error reading or parsing existing JSON file:", e);
  }
}

// Add or update the contract address
deployments.CREATE3Factory = output.returns.factory.value;

// Write the updated JSON data back to the file
const jsonString = JSON.stringify(deployments, null, 2);
await write(deploymentsFilePath, jsonString, { createPath: true });

console.log(`Contract CREATE3Factory address saved to ${deploymentsFilePath}`);