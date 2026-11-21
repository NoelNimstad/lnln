const std = @import("std");
const lnln = @import("lnln.zig").lnln;

pub fn main(init: std.process.Init) !void {
    // Inställningar
    const args = init.minimal.args;
    const args_slice = try args.toSlice(
        init.arena.allocator(),
    );

    if (args_slice.len < 4) {
        std.log.err(
            "Ange CSV-fil, x-osäkerhet och y-osäkerhet!",
            .{},
        );
        return error.BadValue;
    }

    const csv_file_path = args_slice[1];

    // Hämta mätosäkerheter
    const x_uncertainty = try std.fmt.parseFloat(
        f64,
        args_slice[2],
    );

    const y_uncertainty = try std.fmt.parseFloat(
        f64,
        args_slice[3],
    );

    const extension = std.fs.path.extension(csv_file_path);
    if (!std.mem.eql(u8, extension, ".csv")) {
        std.log.err(
            "Förväntade en .csv-fil, hittade {s}!",
            .{extension},
        );
        return error.BadValue;
    }

    const cwd = std.Io.Dir.cwd();

    // Läs fil
    const csv_file = try cwd.readFileAlloc(
        init.io,
        csv_file_path,
        init.gpa,
        .unlimited,
    );
    defer init.gpa.free(csv_file);

    // Ställ in stdout
    var stdout_buffer: [2 << 11]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(
        init.io,
        &stdout_buffer,
    );
    const out = &stdout_writer.interface;

    // lnln
    try lnln(
        csv_file,
        out,
        x_uncertainty,
        y_uncertainty,
    );
}
