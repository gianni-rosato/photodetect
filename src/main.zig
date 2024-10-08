const std = @import("std");
const print = std.debug.print;
const c = @cImport({
    @cInclude("stb_image.h");
});

const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RESET = "\x1b[0m";

const Picture = struct {
    data: [*]u8,
    width: usize,
    height: usize,
    channels: usize,

    fn pictureInit(data: [*]u8, width: c_int, height: c_int, channels: c_int) Picture {
        return .{
            .data = data,
            .width = @intCast(width),
            .height = @intCast(height),
            .channels = @intCast(channels),
        };
    }

    fn calculateEntropy(self: Picture) f64 {
        var histogram = [_]usize{0} ** 256;
        const total_pixels = self.width * self.height;
        const data: [*]const u8 = self.data;

        // Build histogram
        for (0..total_pixels) |i| {
            const pixel_offset = i * self.channels;
            const gray: u8 = @intFromFloat(0.299 * @as(f64, @floatFromInt(data[pixel_offset])) +
                0.587 * @as(f64, @floatFromInt(data[pixel_offset + 1])) +
                0.114 * @as(f64, @floatFromInt(data[pixel_offset + 2])));
            histogram[gray] += 1;
        }

        // Calculate entropy
        var entropy: f64 = 0.0;
        for (histogram) |count| {
            if (count > 0) {
                const probability = @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(total_pixels));
                entropy -= probability * std.math.log2(probability);
            }
        }
        return entropy;
    }

    fn countUniqueColors(self: Picture) !usize {
        var color_set = std.AutoHashMap(u32, void).init(std.heap.page_allocator);
        defer color_set.deinit();

        const total_pixels = self.width * self.height;

        for (0..total_pixels) |i| {
            const pixel_offset = i * self.channels;
            const color: u32 = (@as(u32, self.data[pixel_offset]) << 16) |
                (@as(u32, self.data[pixel_offset + 1]) << 8) |
                @as(u32, self.data[pixel_offset + 2]);
            try color_set.put(color, {});
        }

        return color_set.count();
    }

    fn palletizeImage(self: *Picture, color_depth: u8) void {
        const total_pixels = self.width * self.height;
        const quantize_factor: u16 = @as(u16, 256) / color_depth;

        for (0..total_pixels) |i| {
            const pixel_offset = i * self.channels;
            self.data[pixel_offset] = @intCast(@divFloor(self.data[pixel_offset], quantize_factor) * quantize_factor);
            self.data[pixel_offset + 1] = @intCast(@divFloor(self.data[pixel_offset + 1], quantize_factor) * quantize_factor);
            self.data[pixel_offset + 2] = @intCast(@divFloor(self.data[pixel_offset + 2], quantize_factor) * quantize_factor);
        }
    }
};

fn calculateGeometricMean(entropy: f64, unique_colors: usize) f64 {
    return @sqrt(entropy * @as(f64, @floatFromInt(unique_colors)));
}

fn calculatePhotoConfidence(geometric_mean: f64) struct { is_photo: bool, confidence: f64 } {
    const threshold: f64 = 57.0;
    const z_score: f64 = 2.326; // 98% confidence interval
    const standard_error: f64 = 5.0; // Assumed standard error, adjust as needed

    const is_photo = geometric_mean > threshold;
    const distance_from_threshold: f64 = @abs(geometric_mean - threshold);

    // Calculate confidence using z-score
    var confidence = (distance_from_threshold / (standard_error * z_score)) * 100.0;
    confidence = @min(confidence, 98.0); // Cap at 98% due to our confidence interval

    return .{ .is_photo = is_photo, .confidence = confidence };
}

pub fn main() !void {
    // Get allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Parse args into string array (error union needs 'try')
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        print("Usage: {s} <\x1b[33mimage_file\x1b[0m> <\x1b[33mprint_mode\x1b[0m>\n", .{args[0]});
        print("print mode:\n\t0: pretty\n\t1: verbose\n\t2: boolean\n", .{});
        return error.InvalidArgCount;
    }

    const printmode: u8 = try std.fmt.parseInt(u8, args[2], 10);

    var width: c_int = undefined;
    var height: c_int = undefined;
    var channels: c_int = undefined;

    const img = c.stbi_load(args[1].ptr, &width, &height, &channels, 0);
    defer c.stbi_image_free(img);

    if (img == null) {
        std.debug.print("\x1b[31mError in loading the image\x1b[0m\n", .{});
        return error.ImageLoadFailed;
    }

    if (channels < 3) {
        std.debug.print("\x1b[31mImage must have at least 3 channels (RGB)\x1b[0m\n", .{});
        return error.InvalidChannelCount;
    }

    const color_depth: u8 = 16; // This will reduce colors to 16^3 = 4096 possible colors

    // Initialize picture object
    var image = Picture.pictureInit(img, @intCast(width), @intCast(height), @intCast(channels));

    // Calculate entropy
    const entropy = image.calculateEntropy();

    switch (printmode) {
        1 => {
            // Count unique colors
            const unique_colors = try image.countUniqueColors();

            // Palletize the picture object currently in use
            image.palletizeImage(color_depth);

            // Count unique colors in the picture object after palletization
            const unique_colors_palette = try image.countUniqueColors();

            print("Input image:\t\x1b[33m{s}\x1b[0m\n", .{args[1]});
            print("Image entropy:\t\x1b[33m{d:.6}\x1b[0m\n", .{entropy});
            print("Unique colors:\t\x1b[33m{d}\x1b[0m\n", .{unique_colors});
            print("Pallete colors:\t\x1b[33m{d}\x1b[0m\n", .{unique_colors_palette});

            // Calculate geometric mean
            const geometric_mean = calculateGeometricMean(entropy, unique_colors_palette);
            print("Geometric mean:\t\x1b[32m{d:.6}\x1b[0m\n", .{geometric_mean});

            // Determine if the image is photographic and calculate confidence
            const photo_determination = calculatePhotoConfidence(geometric_mean);
            print("Classification:\t{s}\n", .{
                if (photo_determination.is_photo) "\x1b[32mPhoto\x1b[0m" else "\x1b[33mNonphoto\x1b[0m",
            });

            print("Confidence:\t\x1b[33m{d:.2}%\x1b[0m\n", .{photo_determination.confidence});
        },
        2 => {
            // Palletize the picture object currently in use
            image.palletizeImage(color_depth);

            // Count unique colors in the picture object after palletization
            const unique_colors_palette = try image.countUniqueColors();

            // Calculate geometric mean
            const geometric_mean = calculateGeometricMean(entropy, unique_colors_palette);

            const photo_determination = calculatePhotoConfidence(geometric_mean);
            if (photo_determination.is_photo) {
                print("True\n", .{});
            } else {
                print("False\n", .{});
            }
        },
        else => {
            // Palletize the picture object currently in use
            image.palletizeImage(color_depth);

            // Count unique colors in the picture object after palletization
            const unique_colors_palette = try image.countUniqueColors();

            // Calculate geometric mean
            const geometric_mean = calculateGeometricMean(entropy, unique_colors_palette);
            print("Geometric mean of entropy and palletized unique colors: {d:.6}\n", .{geometric_mean});

            // Determine if the image is photographic and calculate confidence
            const photo_determination = calculatePhotoConfidence(geometric_mean);
            print("The image {s} is {s} photographic with \x1b[33m{d:.2}%\x1b[0m confidence.\n", .{
                args[1],
                if (photo_determination.is_photo) "\x1b[32mlikely\x1b[0m" else "\x1b[33munlikely\x1b[0m to be",
                photo_determination.confidence,
            });
        },
    }
}
