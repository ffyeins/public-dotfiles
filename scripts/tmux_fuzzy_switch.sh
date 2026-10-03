#!/bin/bash
# Fuzzy-find a tmux session or window and switch to it, previewing the window.
# Runs in a popup from prefix + w (.tmux.conf). Type part of a name ("data" for
# "database") and Enter jumps to the top match; Esc closes without switching.
set -uo pipefail

# Preview: the whole window, each pane in its place between borders, with the
# layout shrunk to fit the preview. A pane that shrinks shows its left columns
# and the rows up to its last output, so the prompt stays in view. A zoomed
# window shows just the zoomed pane, as on screen. Perl, because macOS awk
# counts bytes, not characters, and can't cut a line at a column.
if [ "${1:-}" = --preview ]; then
    exec perl - "$2" "${FZF_PREVIEW_COLUMNS:-80}" "${FZF_PREVIEW_LINES:-24}" <<'PERL'
use strict;
use open qw(:std :utf8);

my ($target, $width, $height) = @ARGV;

sub tmux { open(my $out, "-|", "tmux", @_) or return; chomp(my @lines = <$out>); @lines }

my (@panes, $win_w, $win_h);
for (tmux("list-panes", "-t", $target, "-F", "#{pane_id} #{pane_left} #{pane_top} #{pane_width} " .
          "#{pane_height} #{window_width} #{window_height} #{&&:#{window_zoomed_flag},#{!:#{pane_active}}}")) {
    my ($id, $left, $top, $w, $h, $ww, $wh, $hidden) = split;
    ($win_w, $win_h) = ($ww, $wh);
    push @panes, [$id, $left, $top, $w, $h] unless $hidden;
}
exit unless @panes;

# Window column x lands on preview column x * $width / $win_w (rows likewise).
# Panes are placed by their borders, so neighbours still share one
$width = $win_w if $width > $win_w;
$height = $win_h if $height > $win_h;
sub col { int($_[0] * $width / $win_w) }
sub row { int($_[0] * $height / $win_h) }

# The line cut or padded to $w columns, its colours and links closed so they
# don't spill. Tabs (kept by capture-pane) become spaces to the pane's next tab
# stop, else fzf would expand them from the preview's edge and widen the row
sub fit {
    my ($line, $w) = @_;
    my ($out, $used) = ("", 0);
    for ($line =~ /\e\[[\x30-\x3f]*[\x20-\x2f]*[\x40-\x7e]|\e\][^\a\e]*(?:\a|\e\\)?|\X/g) {
        if (/^\e/) { $out .= $_; next }
        my $cells = $_ eq "\t" ? 8 - $used % 8 : /^[\p{Ea=W}\p{Ea=F}]/ ? 2 : 1;
        last if $used + $cells > $w;
        $out .= $_ eq "\t" ? " " x $cells : $_;
        $used += $cells;
    }
    $out .= "\e]8;;\e\\" if $out =~ /\e\]8;/;
    $out . "\e[0m" . " " x ($w - $used);
}

my @owner;  # [row][col]: the pane drawn there; empty for a border
for (@panes) {
    my ($id, $left, $top, $w, $h) = @$_;
    my ($x0, $x1) = ($left ? col($left - 1) + 1 : 0, col($left + $w));
    my ($y0, $y1) = ($top ? row($top - 1) + 1 : 0, row($top + $h));
    next if $x1 <= $x0 || $y1 <= $y0;
    my @lines = tmux("capture-pane", "-ep", "-t", $id);
    my $last = $#lines;
    $last-- while $last >= 0 && $lines[$last] !~ /\S/;
    my $first = $last + 1 - ($y1 - $y0);
    $first = 0 if $first < 0;
    my $pane = { x1 => $x1, y0 => $y0,
                 lines => [map { fit($lines[$first + $_] // "", $x1 - $x0) } 0 .. $y1 - $y0 - 1] };
    for my $y ($y0 .. $y1 - 1) { $owner[$y][$_] = $pane for $x0 .. $x1 - 1 }
}

# Border cells take the line drawing that joins the borders around them:
# indexed by up 1, down 2, left 4, right 8
my $joins = " \x{2502}\x{2502}\x{2502}\x{2500}\x{2518}\x{2510}\x{2524}" .
            "\x{2500}\x{2514}\x{250c}\x{251c}\x{2500}\x{2534}\x{252c}\x{253c}";
sub border { my ($x, $y) = @_; $x >= 0 && $y >= 0 && $x < $width && $y < $height && !$owner[$y][$x] ? 1 : 0 }

for my $y (0 .. $height - 1) {
    my $x = 0;
    while ($x < $width) {
        if (my $pane = $owner[$y][$x]) {
            print $pane->{lines}[$y - $pane->{y0}];
            $x = $pane->{x1};
        } else {
            print substr($joins, border($x, $y - 1) | border($x, $y + 1) << 1 |
                                 border($x - 1, $y) << 2 | border($x + 1, $y) << 3, 1);
            $x++;
        }
    }
    print "\n";
}
PERL
fi

# One line per session followed by its windows, as "target<TAB>label". The "="
# makes the target match the session name exactly. Windows are labelled like the
# status bar: the custom name if renamed, otherwise the current directory.
list() {
    tmux list-windows -a -F "#{session_name}	#{window_index}	#{?automatic-rename,#{b:pane_current_path},#{window_name}}" |
        awk -F '\t' '
            $1 != session { session = $1; print "=" session ":\t" session }
            { print "=" $1 ":" $2 "\t    " $1 ":" $2 "  " $3 }'
}

target=$(list | fzf --reverse --delimiter '\t' --with-nth 2 --accept-nth 1 \
    --preview "'$0' --preview {1}" --preview-window 'right,80%') || exit 0
tmux switch-client -t "$target"
