//
//  SettingsViewController.swift
//  GliderTracker
//
//  Simple Settings with standard UITableView + Emergency System
//
import UIKit
import MapKit
import MessageUI

class SettingsViewController: UIViewController {
    
    private var tableView: UITableView!
    
    // MARK: - Settings Properties
    private var sharePosition: Bool {
        get { UserDefaults.standard.bool(forKey: "sharePosition") }
        set { UserDefaults.standard.set(newValue, forKey: "sharePosition") }
    }
    
    private var showAirspaces: Bool {
        get { UserDefaults.standard.bool(forKey: "showAirspaces") }
        set { UserDefaults.standard.set(newValue, forKey: "showAirspaces") }
    }
    
    private var useMetricUnits: Bool {
        get { UserDefaults.standard.bool(forKey: "useMetricUnits") }
        set { UserDefaults.standard.set(newValue, forKey: "useMetricUnits") }
    }
    
    private var pilotName: String {
        get { UserDefaults.standard.string(forKey: "pilotName") ?? "Unknown Pilot" }
        set { UserDefaults.standard.set(newValue, forKey: "pilotName") }
    }
    
    // Emergency Settings
    private var emergencyEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "emergencyEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "emergencyEnabled") }
    }
    
    private var emergencyContact: String {
        get { UserDefaults.standard.string(forKey: "emergencyContact") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "emergencyContact") }
    }
    
    private var emergencyPhone: String {
        get { UserDefaults.standard.string(forKey: "emergencyPhone") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "emergencyPhone") }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDefaults()
    }
    
    private func setupDefaults() {
        // Set defaults if not already set
        if UserDefaults.standard.object(forKey: "showAirspaces") == nil {
            showAirspaces = true
        }
        if UserDefaults.standard.object(forKey: "useMetricUnits") == nil {
            useMetricUnits = true
        }
    }
    
    private func setupUI() {
        title = "Settings"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func doneTapped() {
        dismiss(animated: true)
    }
    
    @objc private func switchChanged(_ sender: UISwitch) {
        switch sender.tag {
        case 0: sharePosition = sender.isOn
        case 1: showAirspaces = sender.isOn
        case 2: useMetricUnits = sender.isOn
        case 3: emergencyEnabled = sender.isOn
        default: break
        }
    }
}

// MARK: - TableView DataSource & Delegate
extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4 // Pilot, Map, Emergency, About
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2 // Pilot Name, Share Position
        case 1: return 2 // Show Airspaces, Metric Units
        case 2: return 3 // Emergency Enable, Contact, Test
        case 3: return 2 // Version, Build
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Pilot Settings"
        case 1: return "Map & Units"
        case 2: return "Emergency System"
        case 3: return "About"
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 2 {
            return "Emergency system automatically sends SMS alert when rapid descent (>10m/s for 10+ seconds) is detected."
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0): // Pilot Name
            cell.textLabel?.text = "Pilot Name"
            cell.detailTextLabel?.text = pilotName
            cell.accessoryType = .disclosureIndicator
            
        case (0, 1): // Share Position
            cell.textLabel?.text = "Share Position"
            let shareSwitch = UISwitch()
            shareSwitch.isOn = sharePosition
            shareSwitch.tag = 0
            shareSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
            cell.accessoryView = shareSwitch
            cell.selectionStyle = .none
            
        case (1, 0): // Show Airspaces
            cell.textLabel?.text = "Show Airspaces"
            let airspaceSwitch = UISwitch()
            airspaceSwitch.isOn = showAirspaces
            airspaceSwitch.tag = 1
            airspaceSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
            cell.accessoryView = airspaceSwitch
            cell.selectionStyle = .none
            
        case (1, 1): // Metric Units
            cell.textLabel?.text = "Metric Units"
            let metricSwitch = UISwitch()
            metricSwitch.isOn = useMetricUnits
            metricSwitch.tag = 2
            metricSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
            cell.accessoryView = metricSwitch
            cell.selectionStyle = .none
            
        case (2, 0): // Emergency System Enable
            cell.textLabel?.text = "Emergency Detection"
            let emergencySwitch = UISwitch()
            emergencySwitch.isOn = emergencyEnabled
            emergencySwitch.tag = 3
            emergencySwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
            cell.accessoryView = emergencySwitch
            cell.selectionStyle = .none
            
        case (2, 1): // Emergency Contact
            cell.textLabel?.text = "Emergency Contact"
            cell.detailTextLabel?.text = emergencyContact.isEmpty ? "Not Set" : emergencyContact
            cell.accessoryType = .disclosureIndicator
            
        case (2, 2): // Test Emergency
            cell.textLabel?.text = "Test Emergency Alert"
            cell.textLabel?.textColor = .systemOrange
            cell.accessoryType = .disclosureIndicator
            
        case (3, 0): // Version
            cell.textLabel?.text = "Version"
            cell.detailTextLabel?.text = "1.0.0"
            cell.selectionStyle = .none
            
        case (3, 1): // Build
            cell.textLabel?.text = "Build"
            cell.detailTextLabel?.text = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
            cell.selectionStyle = .none
            
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0): // Pilot Name
            showPilotNameAlert()
        case (2, 1): // Emergency Contact
            showEmergencyContactAlert()
        case (2, 2): // Test Emergency
            testEmergencyAlert()
        default:
            break
        }
    }
    
    private func showPilotNameAlert() {
        let alert = UIAlertController(title: "Pilot Name", message: "Enter your pilot name", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = self.pilotName
            textField.placeholder = "Your Name"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let text = alert.textFields?.first?.text, !text.isEmpty {
                self.pilotName = text
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showEmergencyContactAlert() {
        let alert = UIAlertController(title: "Emergency Contact", message: "Enter emergency contact details", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = self.emergencyContact
            textField.placeholder = "Contact Name"
        }
        
        alert.addTextField { textField in
            textField.text = self.emergencyPhone
            textField.placeholder = "+1234567890"
            textField.keyboardType = .phonePad
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let name = alert.textFields?[0].text, !name.isEmpty,
               let phone = alert.textFields?[1].text, !phone.isEmpty {
                self.emergencyContact = name
                self.emergencyPhone = phone
                self.tableView.reloadRows(at: [IndexPath(row: 1, section: 2)], with: .none)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func testEmergencyAlert() {
        guard emergencyEnabled && !emergencyContact.isEmpty && !emergencyPhone.isEmpty else {
            let alert = UIAlertController(title: "Emergency Not Configured",
                                        message: "Please enable emergency detection and set a contact first.",
                                        preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        let alert = UIAlertController(title: "Test Emergency Alert",
                                    message: "This will send a test emergency message to \(emergencyContact). Continue?",
                                    preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Send Test", style: .destructive) { _ in
            self.sendTestEmergencyMessage()
        })
        
        present(alert, animated: true)
    }
    
    private func sendTestEmergencyMessage() {
        // Test emergency message
        let message = "🚨 TEST: Glider Tracker Emergency Alert for \(pilotName). This is a test message. Location: Test coordinates. Time: \(Date())"
        
        if MFMessageComposeViewController.canSendText() {
            let messageController = MFMessageComposeViewController()
            messageController.body = message
            messageController.recipients = [emergencyPhone]
            messageController.messageComposeDelegate = self
            present(messageController, animated: true)
        } else {
            showFallbackAlert(message: message)
        }
    }
    
    private func showFallbackAlert(message: String) {
        let alert = UIAlertController(title: "Test Emergency Message",
                                    message: message,
                                    preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Copy Message", style: .default) { _ in
            UIPasteboard.general.string = message
        })
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - MessageUI Delegate
extension SettingsViewController: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true) {
            var title = "Test Message"
            var message = ""
            
            switch result {
            case .sent:
                title = "Test Sent"
                message = "Emergency test message was sent successfully!"
            case .cancelled:
                title = "Test Cancelled"
                message = "Emergency test was cancelled."
            case .failed:
                title = "Test Failed"
                message = "Failed to send emergency test message."
            @unknown default:
                title = "Unknown Result"
                message = "Unknown result from test message."
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}
