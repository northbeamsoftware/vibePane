import Foundation

final class FileWatcher {
    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private let path: String
    private let onChange: () -> Void

    init(path: String, onChange: @escaping () -> Void) {
        self.path = path
        self.onChange = onChange
        startWatching()
    }

    deinit {
        stopWatching()
    }

    private func startWatching() {
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("FileWatcher: Failed to open file at \(path)")
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source?.setEventHandler { [weak self] in
            self?.onChange()
        }

        source?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        source?.resume()
    }

    func stopWatching() {
        source?.cancel()
        source = nil
    }

    func restart() {
        stopWatching()
        startWatching()
    }
}
