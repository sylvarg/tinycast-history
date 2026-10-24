#!/usr/bin/env python3
"""Writes Tinycast/Resources/PersonalEdition.xcstrings, the personal edition's own string table.

Kept apart from upstream's Localizable.xcstrings so upstream string edits never conflict with ours.
Run after changing STRINGS; `.personal/tests.sh` checks every language is present.
"""
import json
import pathlib

LANGS = ["de", "es", "fr", "ja", "ko", "pt", "ru", "zh-Hans"]
STRINGS = {
    "Clear Launcher History": ["Launcher-Verlauf löschen", "Borrar historial del lanzador",
        "Effacer l’historique du lanceur", "ランチャーの履歴を消去", "런처 기록 지우기",
        "Limpar histórico do iniciador", "Очистить историю запуска", "清除启动器历史记录"],
    "Clear launcher history?": ["Launcher-Verlauf löschen?", "¿Borrar el historial del lanzador?",
        "Effacer l’historique du lanceur ?", "ランチャーの履歴を消去しますか？", "런처 기록을 지울까요?",
        "Limpar o histórico do iniciador?", "Очистить историю запуска?", "清除启动器历史记录？"],
    "Every recalled search goes, and its key with it. This can't be undone.": [
        "Alle gespeicherten Eingaben und ihr Schlüssel werden gelöscht. Dies kann nicht widerrufen werden.",
        "Se borran todas las búsquedas guardadas y su clave. No se puede deshacer.",
        "Toutes les saisies mémorisées sont supprimées, avec leur clé. Cette action est irréversible.",
        "保存された入力とその鍵がすべて削除されます。この操作は取り消せません。",
        "저장된 모든 입력과 해당 키가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.",
        "Todas as pesquisas guardadas e a sua chave são apagadas. Não é possível desfazer.",
        "Все сохранённые запросы и их ключ будут удалены. Это действие нельзя отменить.",
        "所有保存的输入及其密钥都将被删除。此操作无法撤销。"],
    "Clear History": ["Verlauf löschen", "Borrar historial", "Effacer l’historique", "履歴を消去",
        "기록 지우기", "Limpar histórico", "Очистить историю", "清除历史记录"],
    "Couldn’t clear launcher history": ["Launcher-Verlauf konnte nicht gelöscht werden",
        "No se pudo borrar el historial del lanzador", "Impossible d’effacer l’historique du lanceur",
        "ランチャーの履歴を消去できませんでした", "런처 기록을 지울 수 없습니다",
        "Não foi possível limpar o histórico do iniciador", "Не удалось очистить историю запуска",
        "无法清除启动器历史记录"],
    "Launcher history cleared": ["Launcher-Verlauf gelöscht", "Historial del lanzador borrado",
        "Historique du lanceur effacé", "ランチャーの履歴を消去しました", "런처 기록을 지웠습니다",
        "Histórico do iniciador limpo", "История запуска очищена", "已清除启动器历史记录"],
    "Encrypted history unavailable: %@": ["Verschlüsselter Verlauf nicht verfügbar: %@",
        "Historial cifrado no disponible: %@", "Historique chiffré indisponible : %@",
        "暗号化された履歴を利用できません：%@", "암호화된 기록을 사용할 수 없음: %@",
        "Histórico encriptado indisponível: %@", "Зашифрованная история недоступна: %@",
        "加密的历史记录不可用：%@"],
    "Edition": ["Edition", "Edición", "Édition", "エディション", "에디션", "Edição", "Редакция", "版本"],
    "Personal edition with history": ["Persönliche Edition mit Verlauf",
        "Edición personal con historial", "Édition personnelle avec historique",
        "履歴付きの個人版", "기록 기능이 있는 개인판", "Edição pessoal com histórico",
        "Личная редакция с историей", "带历史记录的个人版"],
    "Official base version": ["Offizielle Basisversion", "Versión oficial de base",
        "Version officielle de base", "ベースの公式バージョン", "기반 공식 버전",
        "Versão oficial de base", "Официальная базовая версия", "官方基础版本"],
    "Personal revision": ["Persönliche Revision", "Revisión personal", "Révision personnelle",
        "個人リビジョン", "개인 리비전", "Revisão pessoal", "Личная ревизия", "个人修订版"],
    "Source code and releases": ["Quellcode und Versionen", "Código fuente y versiones",
        "Code source et versions", "ソースコードとリリース", "소스 코드 및 릴리스",
        "Código-fonte e versões", "Исходный код и выпуски", "源代码和发布版本"],
    "Report a problem with this edition": ["Problem mit dieser Edition melden",
        "Informar de un problema con esta edición", "Signaler un problème avec cette édition",
        "このエディションの問題を報告", "이 에디션의 문제 신고", "Comunicar um problema com esta edição",
        "Сообщить о проблеме с этой редакцией", "报告此版本的问题"],
    "Original project by Abue Ammar": ["Originalprojekt von Abue Ammar",
        "Proyecto original de Abue Ammar", "Projet original d’Abue Ammar",
        "Abue Ammar によるオリジナルプロジェクト", "Abue Ammar의 원본 프로젝트",
        "Projeto original de Abue Ammar", "Оригинальный проект Abue Ammar", "Abue Ammar 的原始项目"],
}


def main():
    strings = {}
    for key in sorted(STRINGS):
        values = STRINGS[key]
        assert len(values) == len(LANGS), key
        strings[key] = {
            "extractionState": "manual",
            "localizations": {
                lang: {"stringUnit": {"state": "translated", "value": value}}
                for lang, value in zip(LANGS, values)
            },
        }
    out = pathlib.Path(__file__).resolve().parents[2] / "Tinycast/Resources/PersonalEdition.xcstrings"
    out.write_text(json.dumps({"sourceLanguage": "en", "strings": strings, "version": "1.0"},
                              ensure_ascii=False, indent=2, separators=(",", " : ")) + "\n")


if __name__ == "__main__":
    main()
