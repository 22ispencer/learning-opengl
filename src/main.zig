const std = @import("std");
const c = @cImport({
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

fn key_callback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = scancode;
    _ = mods;
    if (key == c.GLFW_KEY_ESCAPE and action == c.GLFW_PRESS) {
        c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
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

fn check_shader_program_compilation(program: c.GLuint) void {
    // check successful linking
    var success: c_int = undefined;
    var info_log: [512]u8 = undefined;
    var log_length: c_int = undefined;
    c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
    if (success == 0) {
        c.glGetProgramInfoLog(program, 512, &log_length, &info_log[0]);
        std.debug.print("ERROR::SHADER::PROGRAM::COMPILATION_FAILED\n{s}\n", .{info_log[0..@intCast(log_length)]});
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

    _ = c.glfwSetKeyCallback(window, key_callback);

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
    const orange_frag_shader_source = try load_shader_source(allocator, "./src/shaders/orange.frag");
    defer allocator.free(orange_frag_shader_source);

    const orange_frag_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(orange_frag_shader, 1, &orange_frag_shader_source.ptr, null);
    c.glCompileShader(orange_frag_shader);
    check_shader_compilation(orange_frag_shader);

    const pink_frag_source = try load_shader_source(allocator, "./src/shaders/pink.frag");
    defer allocator.free(pink_frag_source);

    const pink_frag_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(pink_frag_shader, 1, &pink_frag_source.ptr, null);
    c.glCompileShader(pink_frag_shader);
    check_shader_compilation(pink_frag_shader);

    // create shader program (link shaders)
    const orange_shader_prog = c.glCreateProgram();
    c.glAttachShader(orange_shader_prog, vertex_shader);
    c.glAttachShader(orange_shader_prog, orange_frag_shader);
    c.glLinkProgram(orange_shader_prog);
    check_shader_program_compilation(orange_shader_prog);

    const pink_shader_prog = c.glCreateProgram();
    c.glAttachShader(pink_shader_prog, vertex_shader);
    c.glAttachShader(pink_shader_prog, pink_frag_shader);
    c.glLinkProgram(pink_shader_prog);
    check_shader_program_compilation(pink_shader_prog);

    // delete shaders now that they are in the program
    c.glDeleteShader(vertex_shader);
    c.glDeleteShader(orange_frag_shader);
    c.glDeleteShader(pink_frag_shader);

    const vertices_1 = [_]c.GLfloat{
        0.5,  0.5,  0.0,
        0.5,  -0.5, 0.0,
        -0.5, 0.5,  0.0,
    };

    const vertices_2 = [_]c.GLfloat{
        0.5,  -0.5, 0.0,
        -0.5, 0.5,  0.0,
        -0.5, -0.5, 0.0,
    };

    // const indices = [_]c.GLuint{
    //     0, 1, 3,
    //     1, 2, 3,
    // };

    var vaos = std.ArrayList(c.GLuint).init(allocator);
    defer vaos.deinit();

    var vbos = std.ArrayList(c.GLuint).init(allocator);
    defer vbos.deinit();

    // define vertex arrays and vertex buffers
    c.glGenVertexArrays(2, try vaos.addManyAsArray(2));
    c.glGenBuffers(2, try vbos.addManyAsArray(2));

    // setup first vao
    c.glBindVertexArray(vaos.items[0]);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbos.items[0]);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices_1)), &vertices_1, c.GL_STATIC_DRAW);

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(c.GLuint), @ptrFromInt(0));
    c.glEnableVertexAttribArray(0);

    // setup second vao
    c.glBindVertexArray(vaos.items[1]);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbos.items[1]);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices_2)), &vertices_2, c.GL_STATIC_DRAW);

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(c.GLuint), @ptrFromInt(0));
    c.glEnableVertexAttribArray(0);

    // Deselect vertex array
    c.glBindVertexArray(0);

    // enable wireframe mode
    // c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_LINE);

    while (c.glfwWindowShouldClose(window) == 0) {
        // set bg color
        c.glClearColor(0.2, 0.3, 0.3, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glUseProgram(orange_shader_prog);
        c.glBindVertexArray(vaos.items[0]);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

        c.glUseProgram(pink_shader_prog);
        c.glBindVertexArray(vaos.items[1]);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);
        // c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, @ptrFromInt(0));
        c.glBindVertexArray(0);

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
