# GitHub, Markdown & Projektstruktur: Kompakter Einstieg

Absolut, es gibt viele gute Einführungen und Best Practices rund um GitHub, Markdown (.md), Repositories und die allgemeine Strukturierung von Projektdokumentation.  
Hier ein kompakter Überblick mit passenden Links und Tipps:

---

## 1. GitHub: Einstieg und Grundlagen

- **Offizielle GitHub-Docs (deutsch/englisch):**  
  [GitHub Docs](https://docs.github.com/de)  
  → Tutorials zu Repos, Branches, Issues, Pull Requests, Organisation etc.

- **GitHub Guides:**  
  [GitHub Guides](https://guides.github.com/)  
  → Schritt-für-Schritt-Anleitungen für Einsteiger.

---

## 2. Markdown (.md): Formatierung & Doku

- **Einfaches Markdown-Tutorial:**  
  [markdownguide.org](https://www.markdownguide.org/)  
  → Alles zur Syntax: Überschriften, Listen, Code, Links, Bilder.

- **GitHub-Flavored Markdown (GFM):**  
  [GitHub Markdown Cheatsheet](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet)

---

## 3. Projektstruktur & Dokumentation

- **README.md:**  
  Immer im Hauptverzeichnis – enthält das Projekthandbuch (Projektbeschreibung, Installation, Beispiele).

- **docs/-Ordner:**  
  Für ausführliche Dokumentation, Tutorials, API-Docs, Charts etc.

- **CONTRIBUTING.md:**  
  Infos für Mitwirkende (z.B. Entwicklungsregeln).

- **CHANGELOG.md:**  
  Versions-Historie.

- **ISSUE_TEMPLATE/ und PULL_REQUEST_TEMPLATE/:**  
  Vorlagen für Issues und Pull Requests.

### Beispielstruktur:
```plaintext
myproject/
├─ README.md
├─ CONTRIBUTING.md
├─ CHANGELOG.md
├─ docs/
│    ├─ index.md
│    ├─ getting-started.md
│    └─ api.md
├─ src/
└─ .github/
     ├─ ISSUE_TEMPLATE/
     └─ workflows/
```

---

## 4. Ordnerstrukturen in GitHub organisieren und editieren

- **Im Browser:**  
  Dateien/Folders in Repos direkt im Web-UI erstellen, verschieben, bearbeiten.

- **Mit VS Code:**  
    - Repo klonen (`git clone ...`)
    - Lokal im Dateisystem beliebig Ordner/Dateien anlegen oder verschieben.
    - Änderungen committen & pushen (`git add .`, `git commit -m "..."`, `git push`)

- **Empfohlene Praxis:**  
    - Klar benannte Ordner (`docs`, `src`, `test`, etc).
    - Dokumentation in Markdown und im `docs/`-Ordner.
    - Automatische Dokumentationsseiten mit GitHub Pages oder Tools wie MkDocs.

---

## 5. Praktische Tutorials für den Einstieg

- [VS Code & GitHub Crashkurs (YouTube, deutsch)](https://www.youtube.com/watch?v=K5uYJn6Qb5M)
- [First Timers Only (englisch, sehr freundlich für Anfänger)](https://www.firsttimersonly.com/)

---

## 6. Best Practices und weiterführende Infos

- [How To Structure (Open Source) Repos](https://github.com/gothinkster/realworld)
- [Awesome README Templates](https://github.com/matiassingers/awesome-readme)
- [Best Practices für Software-Dokumentation](https://documentation.divio.com/)

---

### Kurz:

- Im Zweifel: Immer `README.md` und `docs/`-Ordner nutzen.
- Strukturiere den Code sauber in `src`, `test`, etc.
- Nutze die GitHub-Weboberfläche oder VS Code für alles (inkl. Ordnerstruktur und Markdown).
- Siehe die Links oben für Schritt-für-Schritt-Anleitungen und Best Practices!
