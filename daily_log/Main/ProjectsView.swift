//
//  ProjectsView.swift
//  daily_log
//

import SwiftUI

struct ProjectsView: View {
    @Environment(Store.self) private var store

    @State private var editing: Project?
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "Projects", subtitle: subtitle) {
                HStack(spacing: 6) {
                    TextField("new project", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .onSubmit(addProject)
                    Button("Add", action: addProject)
                        .disabled(Project.slug(newName).isEmpty)
                }
                .controlSize(.small)
            }

            if store.projects.isEmpty {
                EmptyPane(
                    symbol: "tag",
                    title: "No projects yet.",
                    message: "One is created the first time you use a #tag in the capture bar."
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, project in
                            if index > 0 {
                                Divider().opacity(0.5).padding(.leading, 34)
                            }
                            ProjectRow(project: project, rename: { editing = $0 })
                        }
                    }
                    .padding(.vertical, 4)
                    .card()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(item: $editing) { project in
            ProjectEditor(project: project).environment(store)
        }
    }

    private var subtitle: String {
        let active = store.projects.filter { !$0.archived }.count
        let archived = store.projects.count - active
        if store.projects.isEmpty { return "Tags you can use in the capture bar" }
        return archived > 0 ? "\(active) active · \(archived) archived" : "\(active) active"
    }

    private var sorted: [Project] {
        store.projects.sorted {
            $0.archived == $1.archived
                ? $0.name.lowercased() < $1.name.lowercased()
                : !$0.archived
        }
    }

    private func addProject() {
        let key = Project.slug(newName)
        guard !key.isEmpty else { return }
        store.addProject(key: key, name: newName.trimmingCharacters(in: .whitespaces))
        newName = ""
    }
}

// MARK: - Row

private struct ProjectRow: View {
    @Environment(Store.self) private var store

    let project: Project
    let rename: (Project) -> Void

    @State private var hovering = false

    var body: some View {
        let count = store.entryCount(for: project.key)

        HStack(spacing: 10) {
            ProjectDot(key: project.key, size: 8)
                .opacity(project.archived ? 0.4 : 1)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(project.archived ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                Text("#\(project.key) · \(count) \(count == 1 ? "entry" : "entries")")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 12)

            if project.archived {
                Text("archived")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            HStack(spacing: 2) {
                Button("Rename") { rename(project) }
                Button(project.archived ? "Unarchive" : "Archive") {
                    store.setArchived(!project.archived, for: project.key)
                }
                if count == 0 {
                    Button("Delete", role: .destructive) { store.deleteProject(project.key) }
                }
            }
            .buttonStyle(.accessoryBar)
            .controlSize(.small)
            .opacity(hovering ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.05 : 0))
                .padding(.horizontal, 4)
        )
        .onHover { hovering = $0 }
    }
}

// MARK: - Editor

struct ProjectEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let project: Project

    @State private var name = ""
    @State private var key = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ProjectDot(key: Project.slug(key).isEmpty ? project.key : Project.slug(key), size: 9)
                Text("Rename project")
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Name")
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    TextField("", text: $name).frame(width: 240)
                }
                GridRow {
                    Text("Tag").foregroundStyle(.secondary)
                    TextField("", text: $key).frame(width: 240)
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 20)

            if Project.slug(key) != project.key {
                Label(
                    "Changing the tag rewrites \(store.entryCount(for: project.key)) existing entries.",
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            Divider()
                .padding(.top, 18)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    store.renameProject(project.key, toKey: key,
                                        name: name.isEmpty ? project.name : name)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(Project.slug(key).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 420)
        .onAppear {
            name = project.name
            key = project.key
        }
    }
}
