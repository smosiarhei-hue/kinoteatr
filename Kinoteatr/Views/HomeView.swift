import SwiftUI

struct PlayRequest: Identifiable {
    let id = UUID()
    let movie: Movie
    let magnet: MagnetResult
}

struct HomeView: View {
    @StateObject private var viewModel = MovieCatalogViewModel()
    @State private var detailMovie: Movie?
    @State private var pickMovie: Movie?
    @State private var playRequest: PlayRequest?
    @State private var showFilters = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        let minimum: CGFloat = sizeClass == .compact ? 108 : 150
        let maximum: CGFloat = sizeClass == .compact ? 140 : 200
        return [GridItem(.adaptive(minimum: minimum, maximum: maximum), spacing: 14)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if viewModel.useSearch {
                        searchIndicator
                    }
                    filterBar
                    catalogContent
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(appBackground.ignoresSafeArea())
            .navigationTitle("Kinoteatr")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFilters.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Открыть фильтры")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.clearSearch() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Обновить каталог")
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
            .sheet(item: $detailMovie) { movie in
                MovieDetailView(movie: movie) {
                    detailMovie = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        pickMovie = movie
                    }
                }
            }
            .sheet(item: $pickMovie) { movie in
                TorrentPickerView(movie: movie) { magnet in
                    playRequest = PlayRequest(movie: movie, magnet: magnet)
                }
            }
            .sheet(item: $playRequest) { request in
                PlayerView(movie: request.movie, magnet: request.magnet)
                    .preferredColorScheme(.dark)
            }
            .task {
                await viewModel.loadFirst()
            }
        }
    }

    private var appBackground: LinearGradient {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.55)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var searchIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
            Text("Результаты поиска")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.orange)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var catalogContent: some View {
        if viewModel.isLoading && viewModel.movies.isEmpty {
            loadingState
        } else if let error = viewModel.errorMessage, viewModel.movies.isEmpty {
            errorState(error)
        } else {
            LazyVGrid(columns: columns, alignment: .center, spacing: 18) {
                ForEach(viewModel.movies) { movie in
                    MovieCardView(movie: movie) {
                        detailMovie = movie
                    }
                    .task {
                        await viewModel.loadMoreIfNeeded(current: movie)
                    }
                }
            }
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.orange)
            Text("Загрузка фильмов…")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func errorState(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Нет соединения", systemImage: "wifi.exclamationmark")
        } description: {
            Text(error)
        } actions: {
            Button("Повторить") { Task { await viewModel.loadFirst() } }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
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
            .padding(.vertical, 2)
        }
        .accessibilityLabel("Активные фильтры")
    }

    private func filterChip(icon: String, label: String, isOn: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(label)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(isOn ? Color.orange.opacity(0.16) : Color(.tertiarySystemBackground)))
        .overlay(Capsule().stroke(isOn ? Color.orange.opacity(0.28) : Color(.separator).opacity(0.35), lineWidth: 1))
        .foregroundStyle(isOn ? .orange : .secondary)
    }
}
