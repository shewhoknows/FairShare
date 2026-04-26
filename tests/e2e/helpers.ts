import * as fs from 'fs'
import * as path from 'path'

export const AUTH_A = path.join(__dirname, 'setup/.auth-a.json')
export const AUTH_B = path.join(__dirname, 'setup/.auth-b.json')

export function getCredentials(): {
  userA: { name: string; email: string; password: string }
  userB: { name: string; email: string; password: string }
} {
  return JSON.parse(
    fs.readFileSync(path.join(__dirname, 'setup/.credentials.json'), 'utf-8')
  )
}
