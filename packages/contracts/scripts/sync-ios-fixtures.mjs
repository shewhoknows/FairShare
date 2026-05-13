import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(scriptDir, '../../..')
const fixturePath = path.join(repoRoot, 'packages/contracts/fixtures/parity-fixtures.json')
const outputPath = path.join(repoRoot, 'apps/ios/FairShareApp/Sources/ParityFixtures.swift')

const fixture = fs.readFileSync(fixturePath, 'utf8').trim()
const output = `import Foundation

enum ParityFixtures {
    static let json = #"""
${fixture}
"""#
}
`

fs.writeFileSync(outputPath, output)
console.log(`Updated ${path.relative(repoRoot, outputPath)}`)
