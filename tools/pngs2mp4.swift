import AVFoundation
import AppKit
import Foundation

// Stitches a list of PNGs into an H.264 MP4, each frame held for its own
// duration. Written against AVFoundation so the toolchain stays to what
// macOS already ships - no ffmpeg, no Homebrew, nothing to install.
//
// Usage: pngs2mp4 <manifest> <frames dir> <out.mp4>
// Manifest lines: "<filename> <seconds to hold>"

let args = CommandLine.arguments
guard args.count == 4 else {
    FileHandle.standardError.write("usage: pngs2mp4 <manifest> <dir> <out.mp4>\n".data(using: .utf8)!)
    exit(2)
}
let manifestPath = args[1], dir = args[2], outPath = args[3]

struct Shot { let url: URL; let hold: Double }
var shots: [Shot] = []
for line in try String(contentsOfFile: manifestPath, encoding: .utf8)
        .split(separator: "\n") {
    let parts = line.split(separator: " ")
    guard parts.count == 2, let hold = Double(parts[1]) else { continue }
    shots.append(Shot(url: URL(fileURLWithPath: "\(dir)/\(parts[0])"), hold: hold))
}
guard let first = shots.first,
      let probe = NSImage(contentsOf: first.url),
      let probeRep = probe.representations.first else {
    FileHandle.standardError.write("no readable frames\n".data(using: .utf8)!); exit(1)
}

// H.264 requires even dimensions.
let W = probeRep.pixelsWide - (probeRep.pixelsWide % 2)
let H = probeRep.pixelsHigh - (probeRep.pixelsHigh % 2)
let FPS: Int32 = 30

try? FileManager.default.removeItem(atPath: outPath)
let writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: outPath), fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: W,
    AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 6_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
    ],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String: W,
        kCVPixelBufferHeightKey as String: H,
    ])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

func buffer(for url: URL) -> CVPixelBuffer? {
    guard let img = NSImage(contentsOf: url),
          let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { return nil }
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, W, H, kCVPixelFormatType_32ARGB,
                        [kCVPixelBufferCGImageCompatibilityKey: true,
                         kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
                        &pb)
    guard let px = pb else { return nil }
    CVPixelBufferLockBaseAddress(px, [])
    defer { CVPixelBufferUnlockBaseAddress(px, []) }
    guard let ctx = CGContext(
        data: CVPixelBufferGetBaseAddress(px), width: W, height: H,
        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(px),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
    return px
}

var frameIndex: Int64 = 0
for shot in shots {
    guard let px = buffer(for: shot.url) else { continue }
    // Repeat the same buffer for the hold, so a still scene costs one render
    // but still plays at a normal frame rate.
    let repeats = max(1, Int((shot.hold * Double(FPS)).rounded()))
    for _ in 0..<repeats {
        while !input.isReadyForMoreMediaData { usleep(4000) }
        adaptor.append(px, withPresentationTime:
            CMTime(value: frameIndex, timescale: FPS))
        frameIndex += 1
    }
}

input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()

if writer.status == .completed {
    let secs = Double(frameIndex) / Double(FPS)
    print(String(format: "wrote %@ — %dx%d, %.1fs", outPath, W, H, secs))
} else {
    FileHandle.standardError.write("failed: \(writer.error?.localizedDescription ?? "unknown")\n".data(using: .utf8)!)
    exit(1)
}
