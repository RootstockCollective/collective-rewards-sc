import { execSync } from 'child_process';
import { readFileSync, writeFileSync } from 'fs';

// Function to read gas values from a .gas-snapshot file content into an object
function readGasValues(content) {
    const gasValues = {};
    const lines = content.split('\n');
    lines.forEach(line => {
        const match = line.match(/(.*) \(gas: ([0-9]+)\)/);
        if (match) {
            const testName = match[1];
            const gas = parseInt(match[2], 10);
            gasValues[testName] = gas;
        }
    });
    return gasValues;
}

// Get the previous commit hash
const previousCommit = execSync('git rev-parse HEAD~1').toString().trim();

// Read the current .gas-snapshot file
const currentGasSnapshotContent = readFileSync('.gas-snapshot', 'utf-8');

// Read the previous .gas-snapshot file using git show
const previousGasSnapshotContent = execSync(`git show ${previousCommit}:.gas-snapshot`).toString().trim();

// Parse gas values from the current and previous .gas-snapshot contents
const currentGasValues = readGasValues(currentGasSnapshotContent);
const previousGasValues = readGasValues(previousGasSnapshotContent);

// Prepare CSV content
let csvContent = 'Test Name,Current Gas,Previous Gas,Difference\n';
Object.keys(currentGasValues).forEach(testName => {
    const currentGas = currentGasValues[testName];
    const previousGas = previousGasValues[testName] !== undefined ? previousGasValues[testName] : 'N/A';
    const difference = previousGas !== 'N/A' ? currentGas - previousGas : 'N/A';
    csvContent += `${testName},${currentGas},${previousGas},${difference}\n`;
});

// Write CSV content to a file
const outputFilePath = 'gas_comparison.csv';
writeFileSync(outputFilePath, csvContent);

console.log(`Gas comparison written to ${outputFilePath}`);
