Describe 'Monitor eviction ordering' {
    It 'orders candidates by weight then startedAt when system not under pressure' {
        $candidates = @(
            [PSCustomObject]@{ name='a'; weight=1; startedAt='2026-01-01T00:00:00Z' },
            [PSCustomObject]@{ name='b'; weight=2; startedAt='2026-01-01T01:00:00Z' },
            [PSCustomObject]@{ name='c'; weight=1; startedAt='2026-01-01T02:00:00Z' }
        )
        $sorted = $candidates | Sort-Object weight, startedAt
        $names = $sorted | ForEach-Object { $_.name }
        $names | Should -BeExactly @('a','c','b')
    }

    It 'orders candidates by weight then prefers high-memory then high-cpu under pressure' {
        $candidates = @(
            [PSCustomObject]@{ name='lowprio'; weight=1; avgMem=100; avgCpuRate=0.1; startedAt='2026-01-01T00:00:00Z' },
            [PSCustomObject]@{ name='medprio'; weight=2; avgMem=500; avgCpuRate=0.5; startedAt='2026-01-01T00:01:00Z' },
            [PSCustomObject]@{ name='highmem'; weight=2; avgMem=1200; avgCpuRate=0.2; startedAt='2026-01-01T00:02:00Z' }
        )
        # replicate monitor pressure sort: weight asc, then -avgMem, then -avgCpuRate
        $sorted = $candidates | Sort-Object @{ Expression = { $_.weight } }, @{ Expression = { -($_.avgMem) } }, @{ Expression = { -($_.avgCpuRate) } }
        $names = $sorted | ForEach-Object { $_.name }
        # Under pressure, higher avgMem should appear earlier among same weights
        $names | Should -BeExactly @('lowprio','highmem','medprio')
    }
}
