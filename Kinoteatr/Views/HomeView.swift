import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = MovieCatalogViewModel()
    @State private var movieToPlay: Movie?
    @State private var showFilters = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    filterBar
                    if viewModel.isLoading && viewModel.movies.isEmpty {
                        ProgressView("Загрузка…")
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else if let error = viewModel.errorMessage, viewModel.movies.isEmpty {
                        ContentUnavailableView {
                            Label("Ошибка", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Повторить") { Task { await viewModel.loadFirst() } }
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.movies) { movie in
                                MovieCardView(movie: movie) {
                                    movieToPlay = movie
                                }
                                .task {
                                    await viewModel.loadMoreIfNeeded(current: movie)
                                }
                            }
                        }
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Кинотеатр")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFilters.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.clearSearch() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .searchable(text: $viewModel.searchQuery, prompt: "Поиск фильмов")
            .onSubmit(of: .search) {
                Task { await viewModel.runSearch() }
            }
            .sheet(isPresented: $showFilters) {
                FilterSheetView(viewModel: viewModel)
                    .presentationDetents([.large, .medium])
            }
            .sheet(item: $movieToPlay) { movie in
                PlayerView(movie: movie)
                    .preferredColorScheme(.dark)
            }
            .task {
                await viewModel.loadFirst()
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(icon: "arrow.up.arrow.down", label: viewModel.sort.label, isOn: true)
                if let genre = viewModel.selectedGenre {
                    filterChip(icon: "theatermasks", label: genre.name, isOn: true)
                }
                if let year = viewModel.year {
                    filterChip(icon: "calendar", label: "\(year)", isOn: true)
                }
                if viewModel.minRating > 0 {
                    filterChip(icon: "star", label: "\(viewModel.minRating)★+", isOn: true)
                }
            }
        }
    }

    private func filterChip(icon: String, label: String, isOn: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(isOn ? Color.orange.opacity(0.2) : Color(.secondarySystemBackground)))
        .foregroundStyle(isOn ? .orange : .secondary)
    }
}
