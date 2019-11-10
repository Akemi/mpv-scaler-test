import Foundation
import AppKit

//*********************************************************
// some standard settings
//*********************************************************

// file environment
let fileManager         = FileManager.default
let workingDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let scriptPathURL       = URL(fileURLWithPath: CommandLine.arguments[0], relativeTo: workingDirectoryURL)
let scriptDirectoryURL  = scriptPathURL.deletingLastPathComponent()
let mpvpipeURL          = URL(fileURLWithPath: "mpvpipe", relativeTo: scriptDirectoryURL)

let scriptDirectory = scriptDirectoryURL.path
let mpvpipe         = mpvpipeURL.path
let mpv             = "/usr/local/bin/mpv"

// default mpv options for all comparisons
let defMpvArgs: Set = [
    "--no-config",
    "--pause",
    "--no-osc",
    "--osd-level=0",
    "--no-border",
    "--input-file=" + mpvpipe,
    "--vo=libmpv",
    "--dither-depth=8",
    "--fbo-format=rgba16f",
    "--scaler-lut-size=8",
    "--screenshot-format=png",
    "--screenshot-png-compression=0",
    "--screenshot-high-bit-depth=no"
]

// mpv scaler algorithm that will be tested
let scalers: Set = [
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

// mpv scaler windows that will be tested
let scaleWindows: Set = [
    "box",
    "triangle",
    "bartlett",
    "hanning",
    "tukey",
    "hamming",
    "quadric",
    "welch",
    "kaiser",
    "blackman",
    "gaussian",
    "sinc",
    "jinc",
    "sphinx"
]

// blacklist of scalers for the scaler window comparison
// some pointless or duplicate filters
let scalerBlacklistWindow: Set = [
    "bilinear",     //opengl(?)
    "bicubic_fast",
    "oversample",
    "spline16",
    "spline64",
    "ginseng",      //lanczos
    "ewa_lanczos",  //jinc
    "ewa_hanning",  //jinc
    "ewa_ginseng",  //jinc
    "nearest"
]

//*********************************************************
// upscaling settings
//*********************************************************

// test files for upscaling with some default options
let testFilesUp: [[String:Any]] = [
    [ "name" : "gradients", "args" : [ "--geometry=x856" ],  "mult": 3 ],
    [ "name" : "hash",      "args" : [ "--geometry=x856" ],  "mult": 3 ],
    [ "name" : "dot",       "args" : [ "--geometry=x856" ],  "mult": 8 ],
    [ "name" : "rings",     "args" : [ "--geometry=x2200" ], "mult": 1 ],
    [ "name" : "rose",      "args" : [ "--geometry=x856" ],  "mult": 4 ],
    [ "name" : "baby",      "args" : [ "--geometry=x856" ],  "mult": 3 ],
    [ "name" : "test",      "args" : [ "--geometry=x1500" ], "mult": 1 ],
    [ "name" : "shana",     "args" : [ "--geometry=x1200" ], "mult": 2 ]
]

// various test options for upscaling filters
let scalerUpOpts: [[String:Any]] = [
    [ "id" : "norm",             "args" : [ ] ],
    [ "id" : "sigmoid",          "args" : [ "--sigmoid-upscaling=yes" ] ],
    [ "id" : "antiring",         "args" : [ "--scale-antiring=0.85", "--cscale-antiring=0.85" ] ],
    [ "id" : "sigmoid-antiring", "args" : [ "--sigmoid-upscaling=yes", "--scale-antiring=0.85", "--cscale-antiring=0.85" ] ]

]

// opts that were deemed necessary from the previous upscaling test
let scalerUpEssentialOpts: [String] = [
    "--sigmoid-upscaling=yes"
]

//*********************************************************
// downscaling settings
//*********************************************************

// test files for downscaling with some default options
let testFilesDown: [[String:Any]] = [
    [ "name" : "rings-down", "args" : [ "--geometry=x586" ],  "mult": 1 ]
]

// various test options for downscaling filters
let scalerDownOpts: [[String:Any]] = [
    [ "id" : "norm",                     "args" : [ ] ],
    [ "id" : "correct",                  "args" : [ "--correct-downscaling=yes" ] ],
    [ "id" : "correct_sigmoid",          "args" : [ "--correct-downscaling=yes", "--sigmoid-upscaling=yes" ] ],
    [ "id" : "correct_antiring",         "args" : [ "--correct-downscaling=yes", "--dscale-antiring=0.85" ] ],
    [ "id" : "correct_sigmoid_antiring", "args" : [ "--correct-downscaling=yes", "--sigmoid-upscaling=yes", "--dscale-antiring=0.85" ] ]
]

// opts that were deemed necessary from the previous downscaling test
// sigmoid-upscaling implies linear-scaling
let scalerDownEssentialOpts: [String] = [
    "--correct-downscaling=yes",
    "--sigmoid-upscaling=yes"
]

//*********************************************************
// image doubling settings
//*********************************************************

// special image doubling filters with default options
let specialDoublerScalers: [[String:Any]] = [
    [ "id" : "ravu-r4",             "scaler" : "ravu-r4-rgb.hook",         "args" : [ ] ],
    [ "id" : "nnedi3-nns32-win8x6", "scaler" : "nnedi3-nns32-win8x6.hook", "args" : [ "--vf=format=yuv444p" ] ],
    [ "id" : "fsrcnnx-8-0-4-1",     "scaler" : "FSRCNNX_x2_8-0-4-1.glsl",  "args" : [ "--vf=format=yuv444p" ] ],
    [ "id" : "fsrcnnx-16-0-4-1",    "scaler" : "FSRCNNX_x2_16-0-4-1.glsl", "args" : [ "--vf=format=yuv444p" ] ]
]

// various test options for image doubling filters
let specialDoublerScalerOpts: [[String:Any]] = [
    [ "id" : "norm",             "args" : [ ] ],
    [ "id" : "sigmoid",          "args" : [ "--sigmoid-upscaling=yes" ] ],
    [ "id" : "sigmoid_antiring", "args" : [ "--sigmoid-upscaling=yes", "--scale-antiring=0.85", "--cscale-antiring=0.85" ] ]
]

//*********************************************************
// special filters for up- and downscaling
//*********************************************************

// special filters for use after upscaling
let specialUpFilters: [[String:Any]] = [
    [ "id" : "SSimSuperRes_sigmoid", "scaler" : "SSimSuperRes.glsl", "args" : [ ] + scalerUpEssentialOpts ],
    [ "id" : "superxbr_sigmoid",     "scaler" : "superxbr-rgb.hook", "args" : [ ] + scalerUpEssentialOpts ]
]

// special filters for use after downscaling
let specialDownFilters: [[String:Any]] = [
    [ "id" : "SSimDownscaler_sigmoid", "scaler" : "SSimDownscaler.glsl", "args" : [ ] + scalerDownEssentialOpts]
]

//*********************************************************
// own upscaling settings after analysing the scaling tests
// variants:
//      - traditional upscaling settings
//      - with user shader
//
// sinc radius=3 -> lanczos
//*********************************************************
let richter: [[String:Any]] = [
    [ "id"     : "richter-norm",
      "scale"  : "sinc",
      "dscale" : "sinc",
      "args"   : [ "--sigmoid-upscaling=yes",
                   "--sigmoid-center=0.65",
                   "--sigmoid-slope=8.5",
                   "--scale-radius=3",
                   "--cscale-radius=3",
                   "--scale-blur=1.02",
                   "--cscale-blur=1.02",
                   "--cscale-window=hanning",
                   "--scale-window=hanning",
                   "--scale-antiring=0.65",
                   "--cscale-antiring=0.65"
                 ]
    ],
    [ "id"     : "richter-heavy",
      "scale"  : "sinc",
      "dscale" : "sinc",
      "args"   : [ "--sigmoid-upscaling=yes",
                   "--sigmoid-center=0.65",
                   "--sigmoid-slope=10.0",
                   "--scale-radius=3",
                   "--cscale-radius=3",
                   "--scale-blur=1.02",
                   "--cscale-blur=1.02",
                   "--cscale-window=hanning",
                   "--scale-window=hanning",
                   "--scale-antiring=0.65",
                   "--cscale-antiring=0.65",
                   "--vf=format=yuv444p"      // since needi3 only works on Luma
                 ],
      "scaler" : "nnedi3-nns32-win8x6.hook",
    ]
]

//*********************************************************
// helper functions
//*********************************************************

// execute a command line program with arguments
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

// send a command to an open mpv instance
func execMPV(cmd: String) {
    let f = FileHandle(forWritingAtPath: mpvpipe)!
    let bytes: [UInt8] = Array((cmd + "\n").utf8)
    f.write(Data(bytes))
    f.closeFile()
}

// make a screenshot of the current mpv settings
func makeScreen(algo: String, id: String, folder: String, specialArgs: [String],
                switchName: Bool = false, window: String = "", hooks: [String] = [ ])
{
    let testDirectoryURL: URL  = URL(fileURLWithPath: folder, relativeTo: scriptDirectoryURL)
    let testDirectory: String  = testDirectoryURL.path
    let testFile: String       = URL(fileURLWithPath: "original.png", relativeTo: testDirectoryURL).path
    let algoName: String       = algo.replacingOccurrences(of: "_", with: "-")
    let screenshotName: String = switchName ? id + "_" + algoName : algoName + "_" + id
    let screenshotPath: String = URL(fileURLWithPath: screenshotName + ".png", relativeTo: testDirectoryURL).path

    let screenTemplate: [String] = [
        "--screenshot-template=" + screenshotName,
        "--screenshot-directory=" + testDirectory
    ]
    let scaleArgs: [String] = [
        "--scale=" + algo,
        "--cscale=" + algo,
        "--dscale=" + algo
    ]
    let windowArgs: [String] = window.isEmpty ? [] :
        [ "--scale-window=" + window,
          "--cscale-window=" + window,
          "--dscale-window=" + window,
        ]
    let hooksArgs: [String] = hooks.isEmpty ? [] : hooks.map({ "--glsl-shaders-append=" + $0 })

    var args: [String] = scaleArgs + windowArgs + specialArgs
        args           = args + hooksArgs + screenTemplate + [testFile]


    if fileManager.fileExists(atPath: screenshotPath) {
        print("File already exists, not taking screenshot with options: " + args.joined(separator:" "))
        print("-------------------------------------")
    } else {
        print("Taking screenshot with options: " + args.joined(separator:" "))
        print("-------------------------------------")
        let pro: Process = exec(cmd: mpv, args: defMpvArgs + args)
        sleep(2)
        execMPV(cmd: "{ \"command\": [\"screenshot\", \"window\"] }")
        sleep(1)
        execMPV(cmd: "{ \"command\": [\"quit\"] }")
        pro.waitUntilExit()
    }
}

// scaler test for up- and down scaling
func scaleTest(files: [[String:Any]], options: [[String:Any]], filter: [[String:Any]]) {
    for file in files {
        let name = file["name"] as! String
        for algo in scalers {
            for opt in options {
                let id   = opt["id"] as! String
                let args = (file["args"] as! [String]) + (opt["args"] as! [String])
                makeScreen(algo: algo, id: id, folder: name, specialArgs: args)
            }

            for sFilter in filter {
                let id    = sFilter["id"] as! String
                let args  = (file["args"] as! [String]) + (sFilter["args"] as! [String])
                let hooks = [ URL(fileURLWithPath: "hooks/" + (sFilter["scaler"] as! String), relativeTo: scriptDirectoryURL).path ]
                makeScreen(algo: algo, id: id, folder: name, specialArgs: args, hooks: hooks)
            }
        }
    }
}

// scaler window test for up- and down scaling
func windowTest(files: [[String:Any]], args: [String]) {
    for file in files {
        let name = (file["name"] as! String) + "-window"
        let args = (file["args"] as! [String]) + args
        for algo in scalers.subtracting(scalerBlacklistWindow) {
            makeScreen(algo: algo, id: "norm", folder: name, specialArgs: args)
            for window in scaleWindows {
                makeScreen(algo: algo, id: window, folder: name, specialArgs: args, window: window)
            }
        }
    }
}

print("-------------------------------------")
print("Standard mpv args: " + defMpvArgs.joined(separator:" "))
print("-------------------------------------")

// create an mpv input file for commands
mkfifo(mpvpipe, 0o666)

// generate upscaler tests
//scaleTest(files: testFilesUp, options: scalerUpOpts, filter: specialUpFilters)

// generate image doubler tests
for file in testFilesUp {
    for scaler in specialDoublerScalers {
        for opt in specialDoublerScalerOpts {
            let id    = (scaler["id"] as! String) + "_" + (opt["id"] as! String)
            let name  = file["name"] as! String
            let args  = (file["args"] as! [String]) + (scaler["args"] as! [String]) + (opt["args"]! as! [String])
            let hook  = URL(fileURLWithPath: "hooks/" + (scaler["scaler"] as! String), relativeTo: scriptDirectoryURL).path
            let hooks = Array(repeating: hook, count: (file["mult"] as! Int))
            makeScreen(algo: "spline36", id: id, folder: name, specialArgs: args, switchName: true, hooks: hooks)
        }
    }
}

// generate scale window upscaling tests
//windowTest(files: testFilesUp, args: scalerUpEssentialOpts)

// generate downscalers tests
//scaleTest(files: testFilesDown, options: scalerDownOpts, filter: specialDownFilters)

// generate scale window downscaling tests
//windowTest(files: testFilesDown, args: scalerDownEssentialOpts)

// generate my scaling settings tests
/*for file in testFilesUp {
    let name = file["name"] as! String
    for opt in richter {
        let algo  = opt["scale"] as! String
        let id    = opt["id"] as! String
        let args  = (file["args"] as! [String]) + (opt["args"] as! [String])
        let hook  = opt["scaler"] as? String
        let hooks = hook == nil ? [] : [ URL(fileURLWithPath: "hooks/" + hook!, relativeTo: scriptDirectoryURL).path ]
        makeScreen(algo: algo, id: id, folder: name, specialArgs: args, switchName: true, hooks: hooks)
    }
}*/

// play a sound when done
let sound = NSSound(named: "Glass")!
sound.play()
Thread.sleep(forTimeInterval: sound.duration)
