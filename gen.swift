import Foundation

let workingDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let scriptPathURL = URL(fileURLWithPath: CommandLine.arguments[0], relativeTo: workingDirectoryURL)
let scriptDirectoryURL = scriptPathURL.deletingLastPathComponent()
let mpvpipeURL = URL(fileURLWithPath: "mpvpipe", relativeTo: scriptDirectoryURL)

let scriptDirectory = scriptDirectoryURL.path
let mpvpipe = mpvpipeURL.path

let mpv = "/usr/local/bin/mpv"

let stdMpvArgs: [String] = [
    "--no-config",
    "--pause",
    "--no-osc",
    "--no-border",
    "--input-file=" + mpvpipe,
    "--vo=opengl-cb",
    "--dither-depth=8",
    "--fbo-format=rgba16f",
    "--scaler-lut-size=8",
    "--screenshot-format=png",
    "--screenshot-png-compression=0",
    "--screenshot-high-bit-depth=no"
]

let scalers: [String] = [
    "bilinear",
    "bicubic_fast",
    "oversample",
    "spline16",
    "spline36",
    "spline64",
    "sinc",
    "lanczos",
    "ginseng",
    "jinc",
    "ewa_lanczos",
    "ewa_hanning",
    "ewa_ginseng",
    "ewa_lanczossharp",
    "ewa_lanczossoft",
    "haasnsoft",
    "bicubic",
    "bcspline",
    "catmull_rom",
    "mitchell",
    "robidoux",
    "robidouxsharp",
    "ewa_robidoux",
    "ewa_robidouxsharp",
    "box",
    "nearest",
    "triangle",
    "gaussian"
]

let testFiles: [[String:Any]] = [
    [ "name" : "gradients", "args" : [ "--geometry=x856" ],  "mult": 3 ],
    [ "name" : "hash",      "args" : [ "--geometry=x856" ],  "mult": 3 ],
    [ "name" : "dot",       "args" : [ "--geometry=x856" ],  "mult": 8 ],
    [ "name" : "rose",      "args" : [ "--geometry=x856" ],  "mult": 4 ],
    [ "name" : "baby",      "args" : [ "--geometry=x856" ],  "mult": 3 ],
    [ "name" : "test",      "args" : [ "--geometry=x1500" ], "mult": 1 ],
    [ "name" : "shana",     "args" : [ "--geometry=x1200" ], "mult": 2 ],
]

let normScaleSettings: [[String:Any]] = [
    [ "id" : "norm",             "args" : [] ],
    [ "id" : "sigmoid",          "args" : [ "--sigmoid-upscaling=yes" ] ],
    [ "id" : "antiring",         "args" : [ "--scale-antiring=0.85", "--cscale-antiring=0.85" ] ],
    [ "id" : "sigmoid-antiring", "args" : [ "--sigmoid-upscaling=yes", "--scale-antiring=0.85", "--cscale-antiring=0.85" ] ],

]

let specialScalers: [[String:Any]] = [
    [ "id" : "ravu-r4",                              "scaler" : "ravu-r4-rgb.hook",         "args" : [] ],
    [ "id" : "nnedi3-nns32-win8x6",                  "scaler" : "nnedi3-nns32-win8x6.hook", "args" : [ "--vf=format=yuv444p" ]],
    [ "id" : "ravu-r4-sigmoid",                      "scaler" : "ravu-r4-rgb.hook",         "args" : [ "--sigmoid-upscaling=yes" ]],
    [ "id" : "nnedi3-nns32-win8x6-sigmoid",          "scaler" : "nnedi3-nns32-win8x6.hook", "args" : [ "--sigmoid-upscaling=yes", "--vf=format=yuv444p" ] ],

    [ "id" : "ravu-r4-sigmoid-antiring",             "scaler" : "ravu-r4-rgb.hook",         "args" : [ "--sigmoid-upscaling=yes", "--scale-antiring=0.85", "--cscale-antiring=0.85" ]],
    [ "id" : "nnedi3-nns32-win8x6-sigmoid-antiring", "scaler" : "nnedi3-nns32-win8x6.hook", "args" : [ "--sigmoid-upscaling=yes", "--scale-antiring=0.85", "--cscale-antiring=0.85", "--vf=format=yuv444p" ] ],

]

func exec(cmd: String, args: [String]) -> Process {
    let proc = Process()
    proc.launchPath = cmd
    proc.arguments = args
    proc.standardInput = Pipe()
    proc.standardOutput = Pipe()
    proc.standardError = Pipe()
    proc.launch()
    return proc
}

func execMPV(cmd: String) {
    let f = FileHandle(forWritingAtPath: mpvpipe)
    let bytes: [UInt8] = Array((cmd + "\n").utf8)
    f!.write(Data(bytes: bytes))
    f!.closeFile()
}

func makeScreen(algo: String, id: String, folder: String, specialArgs: [String], switchName: Bool = false) {
    let testDirectoryURL = URL(fileURLWithPath: folder, relativeTo: scriptDirectoryURL)
    let testDirectory = testDirectoryURL.path
    let testFile = URL(fileURLWithPath: "original.png", relativeTo: testDirectoryURL).path
    let fileName = switchName ? id + "_" + algo : algo + "_" + id
    let screenTemplate = ["--screenshot-template=" + fileName, "--screenshot-directory=" + testDirectory]
    let scaleArgs = ["--scale=" + algo, "--cscale=" + algo, "--dscale=" + algo]
    let args = scaleArgs + specialArgs + screenTemplate + [testFile]

    print("Taking Screenshot with options: " + args.joined(separator:" "))
    print("-------------------------------------")
    let pro = exec(cmd: mpv, args: stdMpvArgs + args)
    sleep(2)
    execMPV(cmd: "{ \"command\": [\"screenshot\", \"window\"] }")
    sleep(1)
    pro.terminate()
}


print("-------------------------------------")
print("Standard mpv args: " + stdMpvArgs.joined(separator:" "))
print("-------------------------------------")
mkfifo(mpvpipe, 0o666)

for file in testFiles {
    for algo in scalers {
        for setting in normScaleSettings {
            makeScreen(algo: algo, id: setting["id"] as! String, folder: file["name"] as! String, specialArgs: (file["args"] as! [String]) + (setting["args"] as! [String]))
        }
    }
}

for file in testFiles {
    for scaler in specialScalers {
        let hookURL = URL(fileURLWithPath: "hooks/" + (scaler["scaler"] as! String), relativeTo: scriptDirectoryURL)
        let sArgs = Array(repeating: "--glsl-shaders-append=" + hookURL.path, count: (file["mult"] as! Int))
        makeScreen(algo: "spline36", id: scaler["id"] as! String, folder: file["name"] as! String, specialArgs: (file["args"] as! [String]) + (scaler["args"] as! [String]) + sArgs, switchName: true)
    }
}
