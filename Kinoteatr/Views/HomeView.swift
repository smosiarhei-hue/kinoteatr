import SwiftUI

struct PlayRequest: Identifiable {
    let id = UUID()
    let movie: Movie
    let magnet: MagnetResult
}

struct HomeView: View {
    @StateObject private var viewModel = MovieCatalogViewModel()
    @State private var pickMovie: Movie?
    @State private var playRequest: PlayRequest?
    @State private var showFilters = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        switch sizeClass {
        case .compact:
            return [GridItem(.adaptive(minimum: 108, maximum: 136), spacing: 14)]
        default:
            return [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 18)]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroHeader
                    filterBar
                    catalogContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(appBackground.ignoresSafeArea())
            .navigationTitle("Kinoteatr")
            .navigationBarTitleDisplayMode(.inline)
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

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.orange.gradient)
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Kinoteatr")
                        .font(.title2.weight(.bold))
                    Text("Каталог фильмов и быстрый запуск просмотра")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            if viewModel.useSearch {
                Text("Результаты поиска")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        pickMovie = movie
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
                .scaleEffect(1.05)
                .tint(.orange)
            Text("Загрузка фильмов…")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
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
        .frame(maxWidth: .infinity, minHeight: 280)
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
