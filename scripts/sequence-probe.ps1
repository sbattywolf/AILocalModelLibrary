$agents = @('TurboAgent','LocalModelA','LocalModelB','CodeLlama-7B','StarCoder-15B','Mistral-7B','Llama2-13B-Chat')
$py = 'C:\Program Files\Python311\python.exe'
foreach ($a in $agents) {
    Write-Host "--- Agent: $a ---"
    & $py ".\.continue\python\agent_runner.py" -a $a -p 'Probe test'
    Start-Sleep -Milliseconds 200
}
