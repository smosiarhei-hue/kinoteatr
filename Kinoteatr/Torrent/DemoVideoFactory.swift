import AVFoundation
import CoreGraphics
import UIKit

enum DemoVideoFactory {
    static func ensureSampleVideo() async -> URL? {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("Kinoteatr", isDirectory: true)
            .appendingPathComponent("demo_sample.mp4")
        if FileManager.default.fileExists(atPath: dest.path) { return dest }
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        return await generate(into: dest, seconds: 6, width: 640, height: 360, fps: 24)
    }

    private static func generate(into url: URL, seconds: Int, width: Int, height: Int, fps: Int) async -> URL? {
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let totalFrames = seconds * fps
        for frame in 0..<totalFrames {
            while input.isReadyForMoreMediaData == false {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            guard let buffer = makeBuffer(width: width, height: height, frame: frame) else { continue }
            let pts = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps))
            if !adaptor.append(buffer, withPresentationTime: pts) { break }
        }

        input.markAsFinished()
        await writer.finishWriting()
        return writer.status == .completed ? url : nil
    }

    private static func makeBuffer(width: Int, height: Int, frame: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA,
                                         [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        guard status == kCVReturnSuccess, let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let stride = CVPixelBufferGetBytesPerRow(buffer)

        let hue = CGFloat(frame % 240) / 240.0
        let color = UIColor(hue: hue, saturation: 0.7, brightness: 0.9, alpha: 1).cgColor.components ?? [0, 0, 0, 1]
        let b = UInt8(min(color.count > 2 ? color[2] * 255 : 0, 255))
        let g = UInt8(min(color.count > 1 ? color[1] * 255 : 0, 255))
        let r = UInt8(min(color[0] * 255, 255))

        for y in 0..<height {
            let row = base.advanced(by: y * stride).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let i = x * 4
                row[i] = b
                row[i + 1] = g
                row[i + 2] = r
                row[i + 3] = 255
            }
        }
        return buffer
    }
}
