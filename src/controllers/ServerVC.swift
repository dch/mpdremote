// ServerVC.swift
// Copyright (c) 2017 Nyx0uf
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import UIKit


private let headerSectionHeight: CGFloat = 32.0


final class ServerVC : MenuTVC
{
	// MARK: - Private properties
	// MPD Server name
	@IBOutlet fileprivate var tfMPDName: UITextField!
	// MPD Server hostname
	@IBOutlet fileprivate var tfMPDHostname: UITextField!
	// MPD Server port
	@IBOutlet fileprivate var tfMPDPort: UITextField!
	// MPD Server password
	@IBOutlet fileprivate var tfMPDPassword: UITextField!
	// WEB Server hostname
	@IBOutlet fileprivate var tfWEBHostname: UITextField!
	// WEB Server port
	@IBOutlet fileprivate var tfWEBPort: UITextField!
	// Cover name
	@IBOutlet fileprivate var tfWEBCoverName: UITextField!
	// Cell Labels
	@IBOutlet private var lblCellMPDName: UILabel! = nil
	@IBOutlet private var lblCellMPDHostname: UILabel! = nil
	@IBOutlet private var lblCellMPDPort: UILabel! = nil
	@IBOutlet private var lblCellMPDPassword: UILabel! = nil
	@IBOutlet private var lblCellWEBHostname: UILabel! = nil
	@IBOutlet private var lblCellWEBPort: UILabel! = nil
	@IBOutlet private var lblCellWEBCoverName: UILabel! = nil
	@IBOutlet private var lblClearCache: UILabel! = nil
	// MPD Server
	private var mpdServer: AudioServer?
	// WEB Server for covers
	private var webServer: CoverWebServer?
	// Indicate that the keyboard is visible, flag
	private var _keyboardVisible = false
	// Navigation title
	private var titleView: UILabel!

	// MARK: - UIViewController
	override func viewDidLoad()
	{
		super.viewDidLoad()

		// Navigation bar title
		titleView = UILabel(frame: CGRect(0.0, 0.0, 100.0, 44.0))
		titleView.font = UIFont(name: "HelveticaNeue-Medium", size: 14.0)
		titleView.numberOfLines = 2
		titleView.textAlignment = .center
		titleView.isAccessibilityElement = false
		titleView.textColor = #colorLiteral(red: 0.1298420429, green: 0.1298461258, blue: 0.1298439503, alpha: 1)
		titleView.text = NYXLocalizedString("lbl_header_server_cfg")
		navigationItem.titleView = titleView

		if let buttons = self.navigationItem.rightBarButtonItems
		{
			if let search = buttons.filter({$0.tag == 10}).first
			{
				search.accessibilityLabel = NYXLocalizedString("lbl_search_zeroconf")
			}
		}

		lblCellMPDName.text = NYXLocalizedString("lbl_server_name")
		lblCellMPDHostname.text = NYXLocalizedString("lbl_server_host")
		lblCellMPDPort.text = NYXLocalizedString("lbl_server_port")
		lblCellMPDPassword.text = NYXLocalizedString("lbl_server_password")
		lblCellWEBHostname.text = NYXLocalizedString("lbl_server_coverurl")
		lblCellWEBPort.text = NYXLocalizedString("lbl_server_port")
		lblCellWEBCoverName.text = NYXLocalizedString("lbl_server_covername")
		lblClearCache.text = NYXLocalizedString("lbl_server_coverclearcache")
		tfMPDName.placeholder = NYXLocalizedString("lbl_server_defaultname")

		// Keyboard appearance notifications
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShowNotification(_:)), name: .UIKeyboardDidShow, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidHideNotification(_:)), name: .UIKeyboardDidHide, object: nil)
	}

	override func viewWillAppear(_ animated: Bool)
	{
		super.viewWillAppear(animated)

		if let mpdServerAsData = UserDefaults.standard.data(forKey: kNYXPrefMPDServer)
		{
			if let server = NSKeyedUnarchiver.unarchiveObject(with: mpdServerAsData) as! AudioServer?
			{
				mpdServer = server
			}
		}
		else
		{
			Logger.alog("[+] No audio server registered yet.")
		}

		if let webServerAsData = UserDefaults.standard.data(forKey: kNYXPrefWEBServer)
		{
			if let server = NSKeyedUnarchiver.unarchiveObject(with: webServerAsData) as! CoverWebServer?
			{
				webServer = server
			}
		}
		else
		{
			Logger.alog("[+] No web server registered yet.")
		}

		updateFields()
	}

	override var supportedInterfaceOrientations: UIInterfaceOrientationMask
	{
		return .portrait
	}

	override var preferredStatusBarStyle: UIStatusBarStyle
	{
		return .default
	}

	// MARK: - Buttons actions
	@IBAction func validateSettingsAction(_ sender: Any?)
	{
		view.endEditing(true)

		// Check MPD server name (optional)
		var serverName = NYXLocalizedString("lbl_server_defaultname")
		if let strName = tfMPDName.text , strName.length > 0
		{
			serverName = strName
		}

		// Check MPD hostname / ip
		guard let ip = tfMPDHostname.text , ip.length > 0 else
		{
			let alertController = UIAlertController(title: NYXLocalizedString("lbl_alert_servercfg_error"), message:NYXLocalizedString("lbl_alert_servercfg_error_host"), preferredStyle: .alert)
			let cancelAction = UIAlertAction(title: NYXLocalizedString("lbl_ok"), style: .cancel) { (action) in
			}
			alertController.addAction(cancelAction)
			present(alertController, animated: true, completion: nil)
			return
		}

		// Check MPD port
		var port = UInt16(6600)
		if let strPort = tfMPDPort.text, let p = UInt16(strPort)
		{
			port = p
		}

		// Check MPD password (optional)
		var password = ""
		if let strPassword = tfMPDPassword.text , strPassword.length > 0
		{
			password = strPassword
		}

		let mpdServer = AudioServer(name: serverName, hostname: ip, port: port, password: password, type: .mpd)
		let cnn = MPDConnection(mpdServer)
		if cnn.connect()
		{
			self.mpdServer = mpdServer
			let serverAsData = NSKeyedArchiver.archivedData(withRootObject: mpdServer)
			UserDefaults.standard.set(serverAsData, forKey: kNYXPrefMPDServer)

			NotificationCenter.default.post(name: .audioServerConfigurationDidChange, object: mpdServer)
		}
		else
		{
			UserDefaults.standard.removeObject(forKey: kNYXPrefMPDServer)
			let alertController = UIAlertController(title: NYXLocalizedString("lbl_alert_servercfg_error"), message:NYXLocalizedString("lbl_alert_servercfg_error_msg"), preferredStyle: .alert)
			let cancelAction = UIAlertAction(title: NYXLocalizedString("lbl_ok"), style: .cancel) { (action) in
			}
			alertController.addAction(cancelAction)
			present(alertController, animated: true, completion: nil)
		}
		cnn.disconnect()

		// Check web URL (optional)
		if let strURL = tfWEBHostname.text , strURL.length > 0
		{
			var port = UInt16(80)
			if let strPort = tfWEBPort.text, let p = UInt16(strPort)
			{
				port = p
			}

			var coverName = "cover.jpg"
			if let cn = tfWEBCoverName.text , cn.length > 0
			{
				coverName = cn
			}
			let webServer = CoverWebServer(name: "CoverServer", hostname: strURL, port: port, coverName: coverName)
			webServer.coverName = coverName
			self.webServer = webServer
			let serverAsData = NSKeyedArchiver.archivedData(withRootObject: webServer)
			UserDefaults.standard.set(serverAsData, forKey: kNYXPrefWEBServer)
		}
		else
		{
			UserDefaults.standard.removeObject(forKey: kNYXPrefWEBServer)
		}

		UserDefaults.standard.synchronize()
	}

	@IBAction func browserZeroConfServers(_ sender: Any?)
	{
		let sb = UIStoryboard(name: "main", bundle: nil)
		let nvc = sb.instantiateViewController(withIdentifier: "ZeroConfBrowserNVC") as! NYXNavigationController
		let vc = nvc.topViewController as! ZeroConfBrowserTVC
		vc.delegate = self
		self.navigationController?.present(nvc, animated: true, completion: nil)
	}

	// MARK: - Notifications
	func keyboardDidShowNotification(_ aNotification: Notification)
	{
		if _keyboardVisible
		{
			return
		}

		guard let info = aNotification.userInfo else
		{
			return
		}

		guard let value = info[UIKeyboardFrameEndUserInfoKey] as! NSValue? else
		{
			return
		}

		let keyboardFrame = view.convert(value.cgRectValue, from: nil)
		tableView.frame = CGRect(tableView.frame.origin, tableView.frame.width, tableView.frame.height - keyboardFrame.height)
		_keyboardVisible = true
	}

	func keyboardDidHideNotification(_ aNotification: Notification)
	{
		if _keyboardVisible == false
		{
			return
		}

		guard let info = aNotification.userInfo else
		{
			return
		}

		guard let value = info[UIKeyboardFrameEndUserInfoKey] as! NSValue? else
		{
			return
		}

		let keyboardFrame = view.convert(value.cgRectValue, from: nil)
		tableView.frame = CGRect(tableView.frame.origin, tableView.frame.width, tableView.frame.height + keyboardFrame.height)
		_keyboardVisible = false
	}

	// MARK: - Private
	fileprivate func updateFields()
	{
		if let server = mpdServer
		{
			tfMPDName.text = server.name
			tfMPDHostname.text = server.hostname
			tfMPDPort.text = String(server.port)
			tfMPDPassword.text = server.password
		}
		else
		{
			tfMPDName.text = ""
			tfMPDHostname.text = ""
			tfMPDPort.text = "6600"
			tfMPDPassword.text = ""
		}

		if let server = webServer
		{
			tfWEBHostname.text = server.hostname
			tfWEBPort.text = String(server.port)
			tfWEBCoverName.text = server.coverName
		}
		else
		{
			tfWEBHostname.text = ""
			tfWEBPort.text = "80"
			tfWEBCoverName.text = "cover.jpg"
		}

		updateCacheLabel()
	}

	fileprivate func clearCache(confirm: Bool)
	{
		let clearBlock = { () -> Void in
			let fileManager = FileManager()
			let cachesDirectoryURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).last!
			let coversDirectoryName = UserDefaults.standard.string(forKey: kNYXPrefCoversDirectory)!
			let coversDirectoryURL = cachesDirectoryURL.appendingPathComponent(coversDirectoryName)

			do
			{
				try fileManager.removeItem(at: coversDirectoryURL)
				try fileManager.createDirectory(at: coversDirectoryURL, withIntermediateDirectories: true, attributes: nil)
				URLCache.shared.removeAllCachedResponses()
			}
			catch _
			{
				Logger.alog("[!] Can't delete cover cache :<")
			}
			self.updateCacheLabel()
		}

		if confirm
		{
			let alertController = UIAlertController(title: NYXLocalizedString("lbl_alert_purge_cache_title"), message:NYXLocalizedString("lbl_alert_purge_cache_msg"), preferredStyle: .alert)
			let cancelAction = UIAlertAction(title: NYXLocalizedString("lbl_cancel"), style: .cancel) { (action) in
			}
			alertController.addAction(cancelAction)
			let okAction = UIAlertAction(title: NYXLocalizedString("lbl_ok"), style: .destructive) { (action) in
				clearBlock()
			}
			alertController.addAction(okAction)
			present(alertController, animated: true, completion: nil)
		}
		else
		{
			clearBlock()
		}
	}

	fileprivate func updateCacheLabel()
	{
		guard let cachesDirectoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last else {return}
		let size = FileManager.default.sizeOfDirectoryAtURL(cachesDirectoryURL)
		lblClearCache.text = "\(NYXLocalizedString("lbl_server_coverclearcache")) (\(String(format: "%.2f", Double(size) / 1048576.0))\(NYXLocalizedString("lbl_megabytes")))"
	}
}

// MARK: - 
extension ServerVC : ZeroConfBrowserTVCDelegate
{
	func audioServerDidChange()
	{
		clearCache(confirm: false)
	}
}

// MARK: - UITableViewDelegate
extension ServerVC
{
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
	{
		if indexPath.section == 1 && indexPath.row == 3
		{
			clearCache(confirm: true)
		}
		tableView.deselectRow(at: indexPath, animated: true)
	}
}

// MARK: - UITextFieldDelegate
extension ServerVC : UITextFieldDelegate
{
	func textFieldShouldReturn(_ textField: UITextField) -> Bool
	{
		if textField === tfMPDName
		{
			tfMPDHostname.becomeFirstResponder()
		}
		else if textField === tfMPDHostname
		{
			tfMPDPort.becomeFirstResponder()
		}
		else if textField === tfMPDPort
		{
			tfMPDPassword.becomeFirstResponder()
		}
		else if textField === tfMPDPassword
		{
			textField.resignFirstResponder()
		}
		else if textField === tfWEBHostname
		{
			tfWEBPort.becomeFirstResponder()
		}
		else if textField === tfWEBPort
		{
			tfWEBCoverName.becomeFirstResponder()
		}
		else
		{
			textField.resignFirstResponder()
		}
		return true
	}
}

// MARK: - UITableViewDelegate
extension ServerVC
{
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
	{
		let dummy = UIView(frame: CGRect(0.0, 0.0, tableView.width, headerSectionHeight))
		dummy.backgroundColor = tableView.backgroundColor

		let label = UILabel(frame: CGRect(10.0, 0.0, dummy.width - 20.0, dummy.height))
		label.backgroundColor = dummy.backgroundColor
		label.textColor = #colorLiteral(red: 0.2605174184, green: 0.2605243921, blue: 0.260520637, alpha: 1)
		label.font = UIFont.systemFont(ofSize: 15.0)
		dummy.addSubview(label)

		if section == 0
		{
			label.text = NYXLocalizedString("lbl_server_section_server").uppercased()
		}
		else
		{
			label.text = NYXLocalizedString("lbl_server_section_cover").uppercased()
		}

		return dummy
	}

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
	{
		return headerSectionHeight
	}
}
