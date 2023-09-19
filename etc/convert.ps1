class Vec2 {
    [float] $X
    [float] $Y
    Vec2([float] $x, [float] $y) {
        $this.X = $x
        $this.Y = $y
    }
}

class Line {
    [Vec2] $Start
    [Vec2] $End
}

class Glyph {
    [Line[]] $Lines
}

[Glyph[]] $Glyphs = @()

[Vec2] $prev_end

Get-Content -Path ".\font.txt" | % {
    if ($_ -eq "") { return; }
    $Glyph = [Glyph]::new()
    $Strokes = $_.Split(" ")

    $Strokes | % {
        $Vertices = $_.Split(";")
        $Line = [Line]::new()
        if ($Vertices.Count -eq 1) {
            $Components = $Vertices[0].Split(",");
            $Line.Start = $prev_end
            $Line.End   = [Vec2]::new([float]$Components[0], [float]$Components[1])
        } elseif ($Vertices.Count -eq 2) {
            $Start_Components = $Vertices[0].Split(",");
            $End_Components   = $Vertices[1].Split(",");
            $Line.Start = [Vec2]::new([float]$Start_Components[0], [float]$Start_Components[1])
            $Line.End   = [Vec2]::new([float]$End_Components[0], [float]$End_Components[1])
        }
        $Glyph.Lines += $Line
        $prev_end = $Line.End 
    }

    $Glyphs += $Glyph
}

$Output = ""
$Glyphs | % {
    $Output += ".[`n"
    $_.Lines | % {
        $Output += "    .{.{$($_.Start.X), $($_.Start.Y)}, .{$($_.End.X), $($_.End.Y)}},`n"
    }
    $Output += "],`n"
}
$Output | Out-File converted.jai

