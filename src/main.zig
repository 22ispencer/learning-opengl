const std = @import("std");
const c = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

fn load_shader_source(allocator: std.mem.Allocator, path: []const u8) ![:0]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();

    const buffer = try allocator.allocSentinel(u8, file_size, 0);

    const bytes_read = try file.readAll(buffer);
    std.debug.assert(bytes_read == file_size);

    return buffer;
}

fn error_callback(err: c_int, message: [*c]const u8) callconv(.C) void {
    std.debug.print("Error {d}: {s}\n", .{ err, message });
}

fn framebuffer_size_callback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    _ = window;
    c.glViewport(0, 0, width, height);
}

fn process_input(window: ?*c.GLFWwindow) void {
    if (c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS) {
        c.glfwSetWindowShouldClose(window, 1);
    }
}

fn check_shader_compilation(shader: c.GLuint) void {
    var success: c_int = undefined;
    var info_log: [512]u8 = undefined;
    var log_length: c_int = undefined;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        c.glGetShaderInfoLog(shader, 512, &log_length, &info_log[0]);
        std.debug.print("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n{s}\n", .{info_log[0..@intCast(log_length)]});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.debug.print("Memory leak detected", .{});
        }
    }
    const allocator = gpa.allocator();

    const initialized = c.glfwInit();
    if (initialized != 1) {
        std.debug.print("unable to init glfw", .{});
        return;
    }
    defer c.glfwTerminate();

    _ = c.glfwSetErrorCallback(error_callback);

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    const window = c.glfwCreateWindow(800, 600, "LearnOpenGL", null, null);
    if (window == null) {
        std.debug.print("Failed to open window", .{});
    }

    c.glfwMakeContextCurrent(window);
    _ = c.glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

    if (c.gladLoadGLLoader(@ptrCast(&c.glfwGetProcAddress)) == 0) {
        std.debug.print("Unable to initialize GLAD", .{});
    }

    // build and compile shader program
    // --------------------------------
    // create and compile vertex shader
    const vertex_shader_source = try load_shader_source(allocator, "./src/shaders/default.vert");
    defer allocator.free(vertex_shader_source);

    const vertex_shader = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(vertex_shader, 1, &vertex_shader_source.ptr, null);
    c.glCompileShader(vertex_shader);
    check_shader_compilation(vertex_shader);

    // create and compile fragment shader
    const fragment_shader_source = try load_shader_source(allocator, "./src/shaders/default.frag");
    defer allocator.free(fragment_shader_source);

    const fragment_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(fragment_shader, 1, &fragment_shader_source.ptr, null);
    c.glCompileShader(fragment_shader);
    check_shader_compilation(fragment_shader);

    // create shader program (link shaders)
    const shader_program = c.glCreateProgram();
    c.glAttachShader(shader_program, vertex_shader);
    c.glAttachShader(shader_program, fragment_shader);
    c.glLinkProgram(shader_program);

    // check successful linking
    var success: c_int = undefined;
    var info_log: [512]u8 = undefined;
    var log_length: c_int = undefined;
    c.glGetProgramiv(shader_program, c.GL_LINK_STATUS, &success);
    if (success == 0) {
        c.glGetProgramInfoLog(shader_program, 512, &log_length, &info_log[0]);
        std.debug.print("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n{s}\n", .{info_log[0..@intCast(log_length)]});
    }

    // delete shaders now that they are in the program
    c.glDeleteShader(vertex_shader);
    c.glDeleteShader(fragment_shader);

    const vertices = [_]f32{
        -0.5, -0.5, 0.0,
        0.5,  -0.5, 0.0,
        0.0,  0.5,  0.0,
    };

    var VBO: c.GLuint = undefined;
    var VAO: c.GLuint = undefined;
    c.glGenVertexArrays(1, &VAO);
    c.glGenBuffers(1, &VBO);

    c.glBindVertexArray(VAO);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, VBO);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), @ptrFromInt(0));
    c.glEnableVertexAttribArray(0);

    while (c.glfwWindowShouldClose(window) == 0) {
        process_input(window);

        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glUseProgram(shader_program);
        c.glBindVertexArray(VAO);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
