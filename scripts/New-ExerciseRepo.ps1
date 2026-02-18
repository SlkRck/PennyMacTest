<#!
.SYNOPSIS
Creates a GitHub repository for the technical exercise and pushes the completed solution.

.DESCRIPTION
This script bootstraps a new Git repository from the local exercise folder, creates a GitHub repo
(using the GitHub CLI), pushes all content, and prints the URL you can submit to interviewers.

.WHAT THIS SCRIPT DOES
- Validates prerequisites (git + gh)
- Initializes a repo (if needed)
- Creates a GitHub repo under your account/org
- Adds all files, commits, and pushes to origin
- Prints the resulting GitHub URL

.REQUIREMENTS
- Git installed and available on PATH
- GitHub CLI (gh) installed and authenticated (gh auth login)
- Network access to GitHub

.INTENDED USE
Run locally from PowerShell after you’ve reviewed/edited the repo content.

.NOTES
- This script does not run Terraform. It only publishes the repository.
- If you prefer manual creation, you can skip this and create/push via your normal workflow.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    # Path to the local solution folder that should become a GitHub repo.
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoPath = (Resolve-Path -Path (Join-Path $PSScriptRoot '..')).Path,

    # Repository name on GitHub.
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$RepoName = 'pennymac-snapshot-cleaner',

    # Optional GitHub organization (omit to create under your personal account).
    [Parameter(Mandatory = $false)]
    [string]$Org,

    # If set, creates a private repo instead of public.
    [Parameter(Mandatory = $false)]
    [switch]$Private
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Command {
    param([Parameter(Mandatory)][string]$Name)

    if (-not (Get-Command -Name $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH. Install it and try again."
    }
}

Assert-Command -Name 'git'
Assert-Command -Name 'gh'

Write-Verbose "RepoPath: $RepoPath"
Write-Verbose "RepoName: $RepoName"

Push-Location $RepoPath
try {
    # Ensure this is a git repo
    if (-not (Test-Path -Path (Join-Path $RepoPath '.git'))) {
        if ($PSCmdlet.ShouldProcess($RepoPath, 'git init')) {
            git init | Out-Null
        }
    }

    # Ensure main branch
    if ($PSCmdlet.ShouldProcess($RepoPath, 'Ensure main branch')) {
        git checkout -B main | Out-Null
    }

    # Create the GitHub repo
    $visibility = if ($Private) { '--private' } else { '--public' }
    $orgArg = if ($Org) { @('--org', $Org) } else { @() }

    # If repo already exists, gh will error; we surface a clear message.
    if ($PSCmdlet.ShouldProcess("GitHub:$RepoName", 'gh repo create')) {
        gh repo create $RepoName $visibility @orgArg --source . --remote origin --push
    }

    # Ensure all changes are committed (gh --push already pushes, but we keep this robust)
    if ($PSCmdlet.ShouldProcess($RepoPath, 'Commit and push all files')) {
        git add -A

        $hasChanges = -not (git diff --cached --quiet)
        if ($hasChanges) {
            git commit -m "Initial commit: PennyMac technical exercise" | Out-Null
            git push -u origin main | Out-Null
        }
    }

    # Print the URL to submit
    $url = (gh repo view --json url -q .url)
    Write-Host "\nSubmit this GitHub URL to the interviewers:" -ForegroundColor Green
    Write-Host $url -ForegroundColor Green
}
finally {
    Pop-Location
}
