//
//  MasterViewController.swift
//  Shaper3DImport
//
//  Created by Aldrich Co on 7/11/20.
//  Copyright © 2020 Aldrich Co. All rights reserved.
//

import UIKit
import Shapr3DFileConverter

class MasterViewController: UITableViewController {

	var detailViewController: DetailViewController? = nil

	// used to show the file selector dialog to import .shapr files
	// into the app
	lazy var filePicker: ShaprDocumentPicker = {
		return ShaprDocumentPicker(presentationController: self,
								   delegate: self)
	}()
	
	lazy var dataManager: DataManager = {
		let manager = ShaprDataManager()
		manager.delegate = self
		return manager
	}()
	
	lazy var convertQueue: ConvertQueue = {
		let queue = ConversionQueue(converter: Converter())
		return queue
	}()
		
	override func viewDidLoad() {
		super.viewDidLoad()
		
		configureNavigationButtonItems()
		configureSplitViewController()
		
		if dataManager.count() == 0 {
			dataManager.addSampleFiles(5) { (index, isThumbnail) -> Data? in
				ImageUtilities.imageData(hashValue: index,
										 thumb: isThumbnail)
			}
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
		super.viewWillAppear(animated)
	}
	
	private func configureNavigationButtonItems() {
		let addButton = UIBarButtonItem(barButtonSystemItem: .add,
										target: self,
										action: #selector(addButtonPressed(_:)))
		
		navigationItem.leftBarButtonItem = editButtonItem
		navigationItem.rightBarButtonItem = addButton
	}
	
	private func configureSplitViewController() {
		// get a reference to the detail view controller
		if let split = splitViewController {
			let controllers = split.viewControllers
			detailViewController = (controllers.last as? UINavigationController)?
				.topViewController as? DetailViewController
		}
	}
	
	// MARK: - Button Actions
	
	@objc func addButtonPressed(_ sender: Any) {
		guard let bbItem = sender as? UIBarButtonItem else { return }
		filePicker.present(from: bbItem)
	}
	
	// MARK: - Segues

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		
		guard segue.identifier == "showDetail",
			let indexPath = tableView.indexPathForSelectedRow else { return }
		
		let controller = (segue.destination as! UINavigationController)
			.topViewController as! DetailViewController
		
		let object = dataManager.objectAtIndex(indexPath.row)
		controller.item = object
		
		controller.navigationItem.leftBarButtonItem = splitViewController?
			.displayModeButtonItem
		controller.navigationItem.leftItemsSupplementBackButton = true
		
		detailViewController = controller
		detailViewController?.delegate = self
	}
}

extension MasterViewController: ShaprDocumentPickerDelegate {
	
	// handles import
	func didPickDocument(document: ShaprDocument?) {
		guard let doc = document else { return }
		doc.open { [weak self] success in
			if success, let data = doc.data {
				
				let filename = doc.fileURL.lastPathComponent
				
				// need to be the same for both image and thumb
				let hashValue = doc.fileURL.hashValue
				
				let imageData = ImageUtilities
					.imageData(hashValue: hashValue)
				
				let thumbData = ImageUtilities
					.imageData(hashValue: hashValue,
							   thumb: true)
				
				self?.dataManager
					.importFile(filename: filename,
								data: data,
								imageData: imageData,
								thumbnailData: thumbData)
			}
		}
	}
}

extension MasterViewController: DetailViewControllerDelegate {
	
	// handles export
	func detailViewRequestedConversion(baseFileId id: UUID,
									   to format: ShaprOutputFormat) {
		
		guard let file = dataManager.getFileForID(baseFileId: id),
			let fileData = file.data else {
			fatalError("no data found.")
		}
		
		convertQueue.add(id: id, data: fileData,
						 format: format) { [weak self] info  in
			
			self?.dataManager.updateConvertProgress(file: file,
													targetFormat: format,
													progress: info.progress,
													created: info.created,
													data: info.data)
		}
	}
}
