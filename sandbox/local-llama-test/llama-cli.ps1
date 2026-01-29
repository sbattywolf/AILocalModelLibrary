<#
Simple stub that simulates a local LLM CLI for testing. It accepts --model and --prompt and runs a short loop.
Use this script as `LOCAL_LLM_CMD` when testing start/stop scripts.
#>
param(
  [Parameter(ValueFromRemainingArguments=$true)] $Remaining
)

# parse very small arg set
$model = '';
$prompt = '';
for ($i=0; $i -lt $Remaining.Length; $i++) {
  $a = $Remaining[$i]
  if ($a -eq '--model' -and ($i+1 -lt $Remaining.Length)) { $model = $Remaining[$i+1]; $i++ }
  elseif ($a -eq '--prompt' -and ($i+1 -lt $Remaining.Length)) { $prompt = $Remaining[$i+1]; $i++ }
}

Write-Host "[stub-llama] model=$model prompt=$prompt"
Write-Host "[stub-llama] starting simulated work (30s)"
Start-Sleep -Seconds 30
Write-Host "[stub-llama] exiting"
exit 0
