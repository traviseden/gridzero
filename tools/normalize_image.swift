import Foundation
import ImageIO
import UniformTypeIdentifiers

// Rewrite raw pixels without stale simulator EXIF orientation metadata.
guard CommandLine.arguments.count == 3 else { fatalError("Usage: normalize_image.swift input.png output.png") }
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not open artwork")
}
CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: 1] as CFDictionary)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write artwork") }
