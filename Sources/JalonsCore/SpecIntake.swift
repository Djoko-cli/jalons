import Foundation
import UniformTypeIdentifiers

/// Les fichiers que Jalons suit quand le système les lui ouvre (`open -a Jalons`, « Ouvrir avec ») : les mêmes que le
/// menu « Ajouter une feuille de route… », Markdown et texte brut. Le type se lit sur le nom, sans accès au disque.
/// Le Markdown du système (`net.daringfireball.markdown`) est un texte brut : un seul test couvre les deux.
public enum SpecIntake {
    public static func accepts(_ url: URL) -> Bool {
        guard url.isFileURL, !url.hasDirectoryPath,
              let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .plainText)
    }
}
