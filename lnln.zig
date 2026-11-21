const std = @import("std");

pub fn lnln(
    csv: []u8,
    writer: *std.Io.Writer,
    x_uncertainty: f64,
    y_uncertainty: f64,
) !void {
    // LaTeX-huvud
    try writer.writeAll(
        \\\begin{figure}
        \\    \centering
        \\
        \\    \begin{tikzpicture}
        \\        \begin{axis}[
        \\            xlabel={$\ln x$},
        \\            ylabel={$\ln y$},
        \\            grid=both,
        \\            minor grid style={gray!20},
        \\            major grid style={gray!50},
        \\            legend pos=north west,
        \\        ]
        \\    
        \\        \addplot[
        \\           only marks,
        \\           mark=*,
        \\           error bars/.cd,
        \\           x dir=both,
        \\           x explicit,
        \\           y dir=both,
        \\           y explicit,
        \\        ] coordinates {
        \\
    );

    // Bearbeta fil
    var lines = std.mem.splitScalar(
        u8,
        csv,
        '\n',
    );

    var line_number: usize = 0;
    var data_points: usize = 0;

    // Ackumulatorer för trendlinjen
    var sum_x: f64 = 0;
    var sum_y: f64 = 0;
    var sum_xy: f64 = 0;
    var sum_x_squared: f64 = 0;
    var sum_y_squared: f64 = 0;
    var min_x: f64 = std.math.inf(f64);
    var max_x: f64 = -std.math.inf(f64);

    while (lines.next()) |line| {
        line_number += 1;

        if (line.len == 0) continue;
        if (line_number == 1) continue;

        // Hämta värden
        var columns = std.mem.splitScalar(
            u8,
            line,
            ',',
        );

        const x_str = columns.next() orelse continue;
        const y_str = columns.next() orelse continue;

        const x = std.fmt.parseFloat(f64, x_str) catch {
            std.log.err(
                "Ogiltigt x-värde på rad {d}",
                .{line_number},
            );
            return error.InvalidCSV;
        };
        const y = std.fmt.parseFloat(f64, y_str) catch {
            std.log.err(
                "Ogiltigt y-värde på rad {d}",
                .{line_number},
            );
            return error.InvalidCSV;
        };

        if (x <= 0 or y <= 0) {
            std.log.err(
                "Icke-positivt tal på rad {d}",
                .{line_number},
            );
            return error.InvalidData;
        }

        const ln_x = @log(x);
        const ln_y = @log(y);

        // Beräkna felstaplar efter logaritmering
        const ln_x_error = x_uncertainty / x;
        const ln_y_error = y_uncertainty / y;

        // Skriv koordinater med felstaplar
        try writer.print(
            "            ({d}, {d}) +- ({d}, {d})\n",
            .{
                ln_x,
                ln_y,
                ln_x_error,
                ln_y_error,
            },
        );

        // Beräkna data för trendlinjen
        sum_x += ln_x;
        sum_y += ln_y;
        sum_xy += ln_x * ln_y;
        sum_x_squared += ln_x * ln_x;
        sum_y_squared += ln_y * ln_y;

        min_x = @min(min_x, ln_x);
        max_x = @max(max_x, ln_x);

        data_points += 1;
    }

    if (data_points == 0) {
        std.log.err("Inga datapunkter hittades!", .{});
        return error.EmptyData;
    }

    if (data_points < 3) {
        std.log.err(
            "Minst två datapunkter krävs!",
            .{},
        );
        return error.InvalidData;
    }

    // Beräkna linjär regression
    const n: f64 = @floatFromInt(data_points);

    const slope = (n * sum_xy - sum_x * sum_y) /
        (n * sum_x_squared - sum_x * sum_x);

    const intercept = (sum_y - slope * sum_x) / n;

    const r_squared = (sum_xy - sum_x * sum_y / n) *
        (sum_xy - sum_x * sum_y / n) /
        ((sum_x_squared - sum_x * sum_x / n) *
            (sum_y_squared - sum_y * sum_y / n));

    // Beräkna standardfelet för lutningen
    const s_xx = sum_x_squared -
        sum_x * sum_x / n;

    const s_xy = sum_xy -
        sum_x * sum_y / n;

    const s_yy = sum_y_squared -
        sum_y * sum_y / n;

    // Summan av kvadrerade residualer
    const residual_sum = s_yy - slope * s_xy;

    // Residualvarians
    const residual_variance = residual_sum / (n - 2);

    // Standardfel för lutningen
    const slope_error = @sqrt(
        residual_variance / s_xx,
    );

    // Generera trendlinjen
    const trendline_min_y = slope * min_x + intercept;
    const trendline_max_y = slope * max_x + intercept;

    try writer.writeAll(
        \\        };
        \\    
        \\        \addplot[
        \\            red,
        \\            thick,
        \\            no marks,
        \\        ] coordinates {
        \\
    );

    try writer.print(
        "            ({d}, {d})\n",
        .{ min_x, trendline_min_y },
    );

    try writer.print(
        "            ({d}, {d})\n",
        .{ max_x, trendline_max_y },
    );

    // Generera LaTeX-avslutning
    try writer.writeAll(
        \\        };
        \\    
        \\        \end{axis}
        \\    \end{tikzpicture}
        \\
        \\
    );

    try writer.print(
        "    \\caption{{Slope: ${d}\\pm{d}$, $R^2$: ${d}$}}\n",
        .{ slope, slope_error, r_squared },
    );

    try writer.writeAll(
        \\\end{figure}
        \\  
    );

    // Töm stdout-bufferten
    try writer.flush();
}
