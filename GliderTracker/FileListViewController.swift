//
//  FileListViewController.swift
//  GliderTracker
//
//  Enhanced: Multi-Select + Batch Delete + Navigation - FIXED STRUCTURE
//
import UIKit

final class FileListViewController: UITableViewController {

    private var folders: [URL] = []
    private let viewModel: GliderTrackerViewModel
    
    // Multi-Select State
    private var selectedIndexPaths: Set<IndexPath> = []
    private var isInEditMode = false

    // MARK: Init
    init(viewModel: GliderTrackerViewModel) {
        self.viewModel = viewModel
        super.init(style: .insetGrouped)
        title = "Flights"
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupSwipeGesture()
        loadList()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNavigationForEditMode()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("🔙 FileList: viewWillDisappear called")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.allowsMultipleSelectionDuringEditing = true
        
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(loadList), for: .valueChanged)
    }
    
    private func setupNavigationBar() {
        updateNavigationForEditMode()
    }
    
    private func setupSwipeGesture() {
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeBack))
        swipeGesture.direction = .right
        view.addGestureRecognizer(swipeGesture)
    }
    
    @objc private func handleSwipeBack() {
        if !isInEditMode {
            dismissTapped()
        }
    }
    
    private func updateNavigationForEditMode() {
        if isInEditMode {
            // Edit Mode: Show Cancel and Delete buttons
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(cancelEditTapped)
            )
            
            let deleteButton = UIBarButtonItem(
                title: "Delete",
                style: .plain,
                target: self,
                action: #selector(deleteSelectedTapped)
            )
            deleteButton.isEnabled = false
            deleteButton.tintColor = .systemRed
            navigationItem.leftBarButtonItem = deleteButton
            
        } else {
            // Normal Mode: Show Edit and Back buttons
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .edit,
                target: self,
                action: #selector(editTapped)
            )
            
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Back",
                style: .plain,
                target: self,
                action: #selector(dismissTapped)
            )
        }
    }

    // MARK: - Data Loading
    @objc private func loadList() {
        folders = FileManagerService.shared.listFlightFolders()
        tableView.reloadData()
        refreshControl?.endRefreshing()
        
        if folders.isEmpty {
            showEmptyState()
        } else {
            hideEmptyState()
        }
    }
    
    private func showEmptyState() {
        let label = UILabel()
        label.text = "No flights recorded yet\n\nStart tracking to create your first flight"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .body)
        tableView.backgroundView = label
    }
    
    private func hideEmptyState() {
        tableView.backgroundView = nil
    }

    // MARK: - Navigation Actions
    @objc private func dismissTapped() {
        print("🔙 FileList: dismissTapped called")
        
        if let navController = navigationController {
            print("🔙 FileList: Popping view controller")
            navController.popViewController(animated: true)
        } else {
            print("🔙 FileList: Dismissing modal")
            dismiss(animated: true)
        }
    }
    
    @objc private func editTapped() {
        guard !folders.isEmpty else { return }
        setEditing(true, animated: true)
    }
    
    @objc private func cancelEditTapped() {
        setEditing(false, animated: true)
    }
    
    @objc private func deleteSelectedTapped() {
        guard !selectedIndexPaths.isEmpty else { return }
        
        let count = selectedIndexPaths.count
        
        let alert = UIAlertController(
            title: "Delete \(count) Flight\(count > 1 ? "s" : "")?",
            message: "This action cannot be undone.",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            let indexPathsArray = Array(self.selectedIndexPaths)
            self.performBatchDelete(indexPaths: indexPathsArray)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.leftBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func performBatchDelete(indexPaths: [IndexPath]) {
        var deletedURLs: [URL] = []
        var failedURLs: [URL] = []
        
        let urlsToDelete = indexPaths.map { folders[$0.row] }
        
        for url in urlsToDelete {
            if FileManagerService.shared.safeDelete(at: url) {
                deletedURLs.append(url)
            } else {
                failedURLs.append(url)
            }
        }
        
        folders.removeAll { url in
            deletedURLs.contains(url)
        }
        
        selectedIndexPaths.removeAll()
        tableView.reloadData()
        setEditing(false, animated: true)
        
        let deletedCount = deletedURLs.count
        let failedCount = failedURLs.count
        
        if failedCount == 0 {
            showSuccessMessage("Deleted \(deletedCount) flight\(deletedCount > 1 ? "s" : "")")
        } else {
            let message = "Deleted \(deletedCount), failed \(failedCount)"
            showWarningMessage(message)
        }
    }
    
    private func updateDeleteButtonState() {
        navigationItem.leftBarButtonItem?.isEnabled = !selectedIndexPaths.isEmpty
        
        if isInEditMode {
            if selectedIndexPaths.isEmpty {
                title = "Select Flights"
            } else {
                title = "\(selectedIndexPaths.count) Selected"
            }
        } else {
            title = "Flights"
        }
    }
    
    private func showSuccessMessage(_ message: String) {
        let alert = UIAlertController(title: "✅ Success", message: message, preferredStyle: .alert)
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }
    
    private func showWarningMessage(_ message: String) {
        let alert = UIAlertController(title: "⚠️ Warning", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Table View Data Source
    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        folders.count
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let url = folders[indexPath.row]
        
        cell.textLabel?.text = url.lastPathComponent
        cell.accessoryType = isInEditMode ? .none : .detailButton
        
        if let info = FileManagerService.shared.getFileInfo(for: url) {
            cell.detailTextLabel?.text = "\(info.date) • \(info.size)"
        } else {
            cell.detailTextLabel?.text = "File not accessible"
            cell.textLabel?.textColor = .secondaryLabel
        }
        
        return cell
    }

    // MARK: - Table View Delegate
    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isInEditMode {
            selectedIndexPaths.insert(indexPath)
            updateDeleteButtonState()
        } else {
            tv.deselectRow(at: indexPath, animated: true)
            let url = folders[indexPath.row]
            shareFile(at: url)
        }
    }
    
    override func tableView(_ tv: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isInEditMode {
            selectedIndexPaths.remove(indexPath)
            updateDeleteButtonState()
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        isInEditMode = editing
        if !editing {
            selectedIndexPaths.removeAll()
        }
        updateNavigationForEditMode()
        updateDeleteButtonState()
    }
    
    // MARK: - Swipe Actions
    override func tableView(_ tv: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        guard !isInEditMode else { return nil }
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.deleteFile(at: indexPath, completion: completion)
        }
        deleteAction.backgroundColor = .systemRed
        
        let shareAction = UIContextualAction(style: .normal, title: "Share") { [weak self] _, _, completion in
            self?.shareFile(at: self?.folders[indexPath.row])
            completion(true)
        }
        shareAction.backgroundColor = .systemBlue
        
        return UISwipeActionsConfiguration(actions: [deleteAction, shareAction])
    }
    
    private func deleteFile(at indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
        let url = folders[indexPath.row]
        
        guard FileManagerService.shared.exists(at: url) else {
            folders.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            completion(true)
            return
        }
        
        let alert = UIAlertController(
            title: "Delete Flight?",
            message: url.lastPathComponent,
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { completion(false); return }
            
            if FileManagerService.shared.safeDelete(at: url) {
                self.folders.remove(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                completion(true)
            } else {
                self.showWarningMessage("Failed to delete \(url.lastPathComponent)")
                completion(false)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(false)
        })
        
        if let popover = alert.popoverPresentationController {
            if let cell = tableView.cellForRow(at: indexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            } else {
                popover.sourceView = tableView
                popover.sourceRect = CGRect(x: tableView.bounds.midX, y: tableView.bounds.midY, width: 0, height: 0)
            }
        }
        
        present(alert, animated: true)
    }
    
    private func shareFile(at url: URL?) {
        guard let url = url else { return }
        
        guard FileManagerService.shared.exists(at: url) else {
            showWarningMessage("File no longer exists: \(url.lastPathComponent)")
            loadList()
            return
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
}
