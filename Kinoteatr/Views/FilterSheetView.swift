import SwiftUI

struct FilterSheetView: View {
    @ObservedObject var viewModel: MovieCatalogViewModel
    @ObservedObject private var catalog = GenreCatalog.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Сортировка") {
                    Picker("Сортировка", selection: $viewModel.sort) {
                        ForEach(DiscoverSort.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Жанр") {
                    ForEach(catalog.genres) { genre in
                        HStack {
                            Text(genre.name)
                            Spacer()
                            if viewModel.selectedGenre?.id == genre.id {
                                Image(systemName: "checkmark").foregroundStyle(.orange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if viewModel.selectedGenre?.id == genre.id {
                                viewModel.selectedGenre = nil
                            } else {
                                viewModel.selectedGenre = genre
                            }
                        }
                    }
                }

                Section("Год") {
                    Picker("Год", selection: $viewModel.year) {
                        Text("Любой").tag(Int?.none)
                        ForEach(viewModel.years, id: \.self) { y in
                            Text(String(y)).tag(Int?.some(y))
                        }
                    }
                }

                Section("Минимальный рейтинг") {
                    VStack(alignment: .leading) {
                        Text("\(viewModel.minRating, specifier: "%.1f")★ и выше")
                            .foregroundStyle(.orange)
                        Slider(value: $viewModel.minRating, in: 0...9.5, step: 0.5)
                    }
                }

                Button("Сбросить фильтры") {
                    Task {
                        await viewModel.resetFilters()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Фильтры")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Применить") {
                        Task {
                            await viewModel.applyFilters()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}
