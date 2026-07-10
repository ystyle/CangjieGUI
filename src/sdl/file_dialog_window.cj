package cui.sdl

public class FileDialogs {
    /**
     * Throws `CuiException` when dialog options are invalid.
     */
    public static func openFile(
        options!: FileDialogOptions = FileDialogOptions(),
        window!: ?SdlWindow = None
    ): FileDialogRequest {
        let request = createFileDialogRequest(options)
        unsafe {
            SDL_ShowOpenFileDialog(cuiFileDialogCallback, request.userdata(), fileDialogWindow(window),
                request.rawFilters(), request.filterCount(), request.defaultLocation(), options.allowMany)
        }
        request
    }

    /**
     * Throws `CuiException` when dialog options are invalid.
     */
    public static func saveFile(
        options!: FileDialogOptions = FileDialogOptions(),
        window!: ?SdlWindow = None
    ): FileDialogRequest {
        let request = createFileDialogRequest(options)
        unsafe {
            SDL_ShowSaveFileDialog(cuiFileDialogCallback, request.userdata(), fileDialogWindow(window),
                request.rawFilters(), request.filterCount(), request.defaultLocation())
        }
        request
    }

    /**
     * Throws `CuiException` when dialog options are invalid.
     */
    public static func openFolder(
        options!: FileDialogOptions = FileDialogOptions(),
        window!: ?SdlWindow = None
    ): FileDialogRequest {
        let request = createFileDialogRequest(options)
        unsafe {
            SDL_ShowOpenFolderDialog(cuiFileDialogCallback, request.userdata(), fileDialogWindow(window),
                request.defaultLocation(), options.allowMany)
        }
        request
    }
}

extend SdlWindow {
    public func openFileDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest {
        FileDialogs.openFile(options: options, window: Some(this))
    }

    public func saveFileDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest {
        FileDialogs.saveFile(options: options, window: Some(this))
    }

    public func openFolderDialog(options!: FileDialogOptions = FileDialogOptions()): FileDialogRequest {
        FileDialogs.openFolder(options: options, window: Some(this))
    }
}
