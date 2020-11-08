<#
PowerShell version of
https://notebook.community/norvig/pytudes/ipynb/Probability

Relying on the functionality of two external libraries (see lines 22-28)
1. https://www.nuget.org/packages/Fractional.NET/
2. http://download.microsoft.com/download/4/d/3/4d344955-74a0-414e-b541-a3387525aa00/code_mccaffrey.testrun.0510.zip
  - based on this MSDN article https://docs.microsoft.com/en-us/archive/msdn-magazine/2010/may/test-run-combinations-and-permutations-with-fsharp
#>


function gcd ($n1, $n2) {
    $min = $n2
    if ($n1 -lt $n2) {
        $min = $n1
    }
    for ($i = $min; $i -ge 1; $i--) {
        if ($n1 % $i -eq 0 -and $n2 % $i -eq 0) {
            return $i
        }
    }
}
Add-Type -Path "C:\tools\Fractional.NET.1.0.0\lib\netstandard2.0\Fractional.dll"
$libPath = 'c:\scripts\ps1'
#$libPath = 'c:\tools'
$bytes = [IO.File]::ReadAllBytes("$libPath\FSharp.Core.4.5.0\lib\net45\FSharp.Core.dll")
$type = [Reflection.Assembly]::Load($bytes)
$bytes = [IO.File]::ReadAllBytes('c:\tools\Combine.dll')
$type = [Reflection.Assembly]::Load($bytes)

#the code below implements Laplace's quote directly: Probability is thus simply a fraction whose numerator is the number of favorable cases and whose denominator is the number of all the cases possible.
function Get-Probability ($event, $space) {
    $eventHS = [System.Collections.Generic.HashSet[object]]($event)
    $spaceHS = [System.Collections.Generic.HashSet[object]]($space)
    $spaceHS.IntersectWith($eventHS)
    [Fractional.Fractional]::new($spaceHS.count / $space.count,$false).HumanRepresentation
}

$dice = 1, 2, 3, 4, 5, 6
$even = 2, 4, 6

Get-Probability $even $dice

$prime = 2, 3, 5
$odd = 1, 3, 5

#even or prime die roll
Get-Probability (($prime + $even) | select -Unique) $dice

#odd and prime die roll
Get-Probability ($odd | where { $_ -in $prime }) $dice

#card problems
$suits = '♥♠♦♣'
$ranks = 'AKQJT98765432'
$deck = foreach ($suit in $suits.ToCharArray()) { foreach ($rank in $ranks.ToCharArray()) { $suit + $rank } }
$deck.count

#Hands as the sample space of all 5-card combinations from deck.
$c = [Combine.Combin+Combination]::new(52, 5)
$hands = [System.Collections.ArrayList]::new()
while ($c.isLast() -eq $false) { $c = $c.Successor(); $null = $hands.Add($c.ApplyTo($deck) -join ',') }
$hands.Count
$indices = get-random -InputObject (0..($hands.count - 1)) -count 7
$sample = $hands[$indices]
#Now we can answer questions like the probability of being dealt a flush (5 cards of the same suit):
$regex = $suits.ToCharArray() -join '|'
$flushes = $hands.where{[regex]::match(([regex]::matches($_,$regex)).Value -join '','(.)\1{4}').Success}
$flushes = $hands.where{([System.Collections.Generic.HashSet[char]]@([regex]::matches($_,$regex).Value)).Count -eq 1}
$flushes = $hands.where{([regex]::matches($_,$regex) | group value -NoElement).Count -eq 5}
$flushes = $hands.where{[regex]::match(([regex]::matches($_,$regex)).Value -join '','(.)\1{4}').Success}
$flushes = $hands.where{([System.Collections.Generic.HashSet[char]]@([regex]::matches($_,$regex).Value)).Count -eq 1}


$handsArr = $hands.ToArray()
[Func[object, bool]] $delegate = { param($d); return ([System.Collections.Generic.HashSet[char]]@([regex]::matches($d, '♥|♠|♦|♣').Value)).Count -eq 1 }
$flushes = [Linq.Enumerable]::ToArray([Linq.Enumerable]::Where($handsArr, $delegate))

$arr = [Collections.Generic.List[Object]]::new()
$arr.AddRange($hands.ToArray())
$flushes = $arr.FindAll( { ([System.Collections.Generic.HashSet[object]]([regex]::Matches($args[0], '[^\w|,]').Value)).Count -eq 1 })
[fractional.fractional]::new($flushes.count / $hands.count,$false).HumanRepresentation

#Or the probability of four of a kind
$four_of_a_kind = $arr.FindAll( { @([regex]::Matches($args[0], '\w') | group Value -NoElement | where { $_.count -eq 4 }).count })
[fractional.fractional]::new($four_of_a_kind.count / $hands.count,$false).HumanRepresentation

#urn problems
<#
An urn contains 6 blue, 9 red, and 8 white balls. We select six balls at random. What is the probability of each of these outcomes:

All balls are red.
3 are blue, and 1 is red, and 2 are white, .
Exactly 4 balls are white.
#>

function balls($color, $n) {
    foreach ($i in 1..($n)) {
        $color + $i
    }
}
$urn = (balls B 6) + (balls R 9) + (balls W 8)

#Now we can define the sample space, U6, as the set of all 6-ball combinations:

$u6 = [System.Collections.ArrayList]::new()
$c = [Combine.Combin+Combination]::new($urn.count, 6)
while ($c.isLast() -eq $false) { $c = $c.Successor(); $null = $u6.Add($c.ApplyTo($urn) -join ',') }

#Define select such that select('R', 6) is the event of picking 6 red balls from the urn:
function GetFromUrn ($color, $n, $space = $u6) {
    $arr = [Collections.Generic.List[Object]]::new()
    $arr.AddRange($space.ToArray())
    $arr.FindAll( { [regex]::matches($args[0], $color).Value.Count -eq $n } )
}
[fractional.fractional]::new((GetFromUrn R 6).count / $u6.count,$false).HumanRepresentation

#need to use set intersection
$b3 = GetFromUrn B 3
$b3 = [System.Collections.Generic.HashSet[object]]($b3)
$r1 = GetFromUrn R 1
$r1 = [System.Collections.Generic.HashSet[object]]($r1)
$b3.InterSectWith($r1)
[fractional.fractional]::new($b3.count / $u6.count,$false).HumanRepresentation

[fractional.fractional]::new((GetFromUrn W 4).count / $u6.Count,$false).HumanRepresentation

<#
Urn problems via arithmetic
Let's verify these calculations using basic arithmetic, rather than exhaustive counting. First, how many ways can I choose 6 out of 9 red balls?
It could be any of the 9 for the first ball, any of 8 remaining for the second, and so on down to any of the remaining 4 for the sixth and final ball.
But we don't care about the order of the six balls, so divide that product by the number of permutations of 6 things,
which is 6!, giving us 9 × 8 × 7 × 6 × 5 × 4 / 6! = 84.
In general, the number of ways of choosing c out of n items is (n choose c) = n! / ((n - c)! × c!). We can translate that to code:
#>
[Combine.Combin+Combination]::Choose(9, 6)
$b3.count -eq ([Combine.Combin+Combination]::Choose(6, 3) * [Combine.Combin+Combination]::Choose(8, 2) * [Combine.Combin+Combination]::Choose(9, 1))


#We can solve all these problems just by counting; all you ever needed to know about probability problems you learned from Sesame Street:
<#
So far, we have accepted Laplace's assumption that nothing leads us to expect that any one of these cases should occur more than any other. In real life, we often get outcomes that are not equiprobable--for example, a loaded die favors one side over the others. We will introduce three more vocabulary items:

Frequency: a non-negative number describing how often an outcome occurs. Can be a count like 5, or a ratio like 1/6.

Distribution: A mapping from outcome to frequency of that outcome. We will allow sample spaces to be distributions.

Probability Distribution: A probability distribution is a distribution whose frequencies sum to 1.

I could implement distributions with Dist = dict, but instead I'll make Dist a subclass collections.Counter:
#>
function Get-ProbabilityDist ($event, $space) {
    $spaceCount = [Linq.Enumerable]::Sum([double[]]$space.Values)
    $eventCount = [Linq.Enumerable]::Sum([double[]]$space[$event])
    $eventCount / $spaceCount
}
#For example, here's the probability of rolling an even number with a crooked die that is loaded to prefer 6:
$crooked = @{1 = 0.1; 2 = 0.1; 3 = 0.1; 4 = 0.1; 5 = 0.1; 6 = 0.5 }
Get-ProbabilityDist (2, 4, 6) $crooked

<#
As another example, an article gives the following counts for two-child families in Denmark, where GB means a family where the first child
is a girl and the second a boy (I'm aware that not all births can be classified as the binary "boy" or "girl," but the data was reported that way):
#>
$dk = @{GG = 121801; GB = 126840; BG = 127123; BB = 135138 }
$first_girl = 'GG', 'GB'
Get-ProbabilityDist $first_girl $dk

#Given the first child, are you more likely to have a second child of the same sex?
$same = 'GG', 'BB'
Get-ProbabilityDist $same $dk
