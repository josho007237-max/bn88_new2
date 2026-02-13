param(
  [string]$DbPath = "",
  [string]$OutDir = ".\\backups"
)

$ErrorActionPreference = "Stop"

function Resolve-DbPath([string]$PathArg) {
  if ($PathArg) {
    return (Resolve-Path -Path $PathArg).Path
  }

  $dbUrl = $env:DATABASE_URL
  if ($dbUrl -and $dbUrl.StartsWith("file:")) {
    $raw = $dbUrl.Substring(5)
    return (Resolve-Path -Path $raw).Path
  }

  return (Resolve-Path -Path ".\\dev.db").Path
}

$resolvedDb = Resolve-DbPath $DbPath
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = Join-Path $OutDir "db-$ts.sqlite"
Copy-Item -Path $resolvedDb -Destination $backupFile -Force
Write-Host "DB backup -> $backupFile"

$manifestFile = Join-Path $OutDir "media-manifest-$ts.json"
$env:MEDIA_MANIFEST_OUT = $manifestFile
node -e "const fs=require('fs');const {PrismaClient}=require('@prisma/client');(async()=>{const out=process.env.MEDIA_MANIFEST_OUT;const p=new PrismaClient();const items=await p.mediaAsset.findMany({select:{id:true,tenant:true,provider:true,contentId:true,storageKey:true,mimeType:true,size:true,chatMessageId:true,sessionId:true,createdAt:true}});fs.writeFileSync(out, JSON.stringify(items,null,2));await p.$disconnect();console.log('Media manifest ->', out);})().catch(e=>{console.error(e);process.exit(1);});"