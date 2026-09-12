import SwiftUI
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }
  var data: LocalData
  init(data: LocalData) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    guard let bytes = configuration.file.regularFileContents, bytes.count <= 10_000_000 else {
      throw CocoaError(.fileReadCorruptFile)
    }
    data = try JSONDecoder().decode(LocalData.self, from: bytes).validated()
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return FileWrapper(regularFileWithContents: try encoder.encode(data))
  }
}
