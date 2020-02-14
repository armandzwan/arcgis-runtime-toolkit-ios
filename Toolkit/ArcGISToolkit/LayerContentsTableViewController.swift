//
// Copyright 2020 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ArcGIS

let initialIndentation: CGFloat = 16.0

class LegendInfoCell: UITableViewCell {
    var legendInfo: AGSLegendInfo? {
        didSet {
            nameLabel.text = legendInfo?.name
        }
    }
    
    var symbolImage: UIImage? {
        didSet {
            legendImageView.image = symbolImage
            activityIndicatorView.isHidden = (symbolImage != nil)
        }
    }
    
    var layerIndentationLevel: Int = 0 {
        didSet {
            indentationConstraint.constant = CGFloat(layerIndentationLevel) * 8.0 + initialIndentation
        }
    }
    
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var legendImageView: UIImageView!
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet var indentationConstraint: NSLayoutConstraint!
}

class LayerCell: UITableViewCell {
    var layerContent: AGSLayerContent? {
        didSet {
            nameLabel.text = layerContent?.name
        }
    }
    
    var showLayerAccordian: Bool = false {
        didSet {
            accordianButton.isHidden = !showLayerAccordian
            accordianButtonWidthConstraint.constant = showLayerAccordian ? accordianButton.frame.height : 0.0
//            NSLayoutConstraint.activate([accordianButton.widthAnchor.constraint(equalToConstant: showLayerAccordian ? accordianButton.frame.height : 0.0)])
        }
    }
    
    var showLayerVisibility: Bool = false {
        didSet {
            visibilitySwitch.isHidden = !showLayerVisibility
        }
    }
    
    var layerIndentationLevel: Int = 0 {
        didSet {
            indentationConstraint.constant = CGFloat(layerIndentationLevel) * 8.0 + initialIndentation
        }
    }
    
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var accordianButton: UIButton!
    @IBOutlet var visibilitySwitch: UISwitch!
    @IBOutlet var indentationConstraint: NSLayoutConstraint!
    @IBOutlet var accordianButtonWidthConstraint: NSLayoutConstraint!

    @IBAction func accordianAction(_ sender: Any) {
    }
    
    @IBAction func visibilityChanged(_ sender: Any) {
        layerContent?.isVisible = (sender as! UISwitch).isOn
    }
}

class LayerContentsTableViewController: UITableViewController {
    var legendInfoCellReuseIdentifier = "LegendInfo"
    var layerCellReuseIdentifier = "LayerTitle"
    var sublayerCellReuseIdentifier = "SublayerTitle"
    
    var geoView: AGSGeoView?
    
    // This is the array of data to display.  It can contain either:
    // layers of type AGSLayers,
    // sublayers which implement AGSLayerContent but are not AGSLayers,
    // legend infos of type AGSLegendInfo
    var contents = [AnyObject]() {
        didSet {
            tableView.reloadData()
        }
    }
    
    var config: LayerContentsConfiguration = LayerContentsViewController.TableOfContents() {
        didSet {
            tableView.separatorStyle = config.showRowSeparator ? .singleLine : .none
            title = config.title
            tableView.reloadData()
        }
    }
    
    // dictionary of symbol swatches (images); keys are the symbol used to create the swatch
    private var symbolSwatches = [AGSSymbol: UIImage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
//        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
//        self.parent?.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, take into account configuration
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, take into account configuration
        return contents.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Create and configure the cell...
        var cell: UITableViewCell!
        let rowItem: AnyObject = contents[indexPath.row]
        switch rowItem {
        case let layer as AGSLayer:
            // rowItem is a layer
            let layerCell = tableView.dequeueReusableCell(withIdentifier: layerCellReuseIdentifier) as! LayerCell
            cell = layerCell
            layerCell.layerContent = layer
            layerCell.showLayerAccordian = config.allowLayersAccordion
            layerCell.showLayerVisibility = config.allowToggleVisibility && layer.canChangeVisibility
        case let layerContent as AGSLayerContent:
            // rowItem is not a layer, but still implements AGSLayerContent, so it's a sublayer
            let layerCell = tableView.dequeueReusableCell(withIdentifier: sublayerCellReuseIdentifier) as! LayerCell
            cell = layerCell
            layerCell.layerContent = layerContent
            layerCell.showLayerAccordian = config.allowLayersAccordion
            layerCell.showLayerVisibility = config.allowToggleVisibility && layerContent.canChangeVisibility
        case let legendInfo as AGSLegendInfo:
            // rowItem is a legendInfo
            let layerInfoCell = tableView.dequeueReusableCell(withIdentifier: legendInfoCellReuseIdentifier) as! LegendInfoCell
            cell = layerInfoCell
            layerInfoCell.legendInfo = legendInfo
            layerInfoCell.layerIndentationLevel = 0
            
            //            let imageview = cell.viewWithTag(LegendViewController.imageViewTag) as? UIImageView
            if let symbol = legendInfo.symbol {
                //                let activityIndicator = cell.viewWithTag(LegendViewController.activityIndicatorTag) as! UIActivityIndicatorView
                if let swatch = self.symbolSwatches[symbol] {
                    // We have a swatch, so set it into the imageView and stop the activity indicator
                    layerInfoCell.symbolImage = swatch
                    //                    activityIndicator.stopAnimating()
                } else {
                    // Tag the cell so we know what index path it's being used for
                    cell.tag = indexPath.hashValue
                    layerInfoCell.symbolImage = nil
                    
                    // We don't have a swatch for the given symbol, so create the swatch
                    symbol.createSwatch(completion: { [weak self] (image, _) -> Void in
                        // Make sure this is the cell we still care about and that it
                        // wasn't already recycled by the time we get the swatch
                        if cell.tag != indexPath.hashValue {
                            return
                        }
                        
                        // set the swatch into our dictionary and reload the row
                        self?.symbolSwatches[symbol] = image
                        layerInfoCell.symbolImage = image
                        //                        tableView.reloadRows(at: [indexPath], with: .automatic)
                    })
                }
            }
        default:
            cell = UITableViewCell()
            cell.textLabel?.text = "No Data"
        }
        //        if let layer = rowItem as? AGSLayer {
        //            // item is a layer
        //            let layerCell = tableView.dequeueReusableCell(withIdentifier: layerCellReuseIdentifier) as! LayerCell
        //            cell = layerCell
        //            layerCell.name = layer.name
        ////            cell.layer = layer
        ////            let textLabel = cell.viewWithTag(LegendViewController.labelTag) as? UILabel
        ////            textLabel?.text = layer.name
        //        } else if let layerContent = rowItem as? AGSLayerContent {
        //            // item is not a layer, but still implements AGSLayerContent
        //            // so it's a sublayer
        //            let layerCell = tableView.dequeueReusableCell(withIdentifier: sublayerCellReuseIdentifier) as! LayerCell
        //            cell = layerCell
        //            layerCell.name = layerContent.name
        ////            let textLabel = cell.viewWithTag(LegendViewController.labelTag) as? UILabel
        ////            textLabel?.text = layerContent.name
        //        } else if let legendInfo = rowItem as? AGSLegendInfo {
        //            // item is a legendInfo
        //            let layerInfoCell = tableView.dequeueReusableCell(withIdentifier: legendInfoCellReuseIdentifier) as! LegendInfoCell
        //            cell = layerInfoCell
        //            layerInfoCell.name = legendInfo.name
        ////            let textLabel = cell.viewWithTag(LegendViewController.labelTag) as? UILabel
        ////            textLabel?.text = legendInfo.name
        //
        ////            let imageview = cell.viewWithTag(LegendViewController.imageViewTag) as? UIImageView
        ////            if let symbol = legendInfo.symbol {
        ////                let activityIndicator = cell.viewWithTag(LegendViewController.activityIndicatorTag) as! UIActivityIndicatorView
        ////
        ////                if let swatch = self.symbolSwatches[symbol] {
        ////                    // we have a swatch, so set it into the imageView and stop the activity indicator
        ////                    imageview?.image = swatch
        ////                    activityIndicator.stopAnimating()
        ////                } else {
        ////                    // tag the cell so we know what index path it's being used for
        ////                    cell.tag = indexPath.hashValue
        ////
        ////                    // we don't have a swatch for the given symbol, start the activity indicator
        ////                    // and create the swatch
        ////                    activityIndicator.startAnimating()
        ////                    symbol.createSwatch(completion: { [weak self] (image, _) -> Void in
        ////                        // make sure this is the cell we still care about and that it
        ////                        // wasn't already recycled by the time we get the swatch
        ////                        if cell.tag != indexPath.hashValue {
        ////                            return
        ////                        }
        ////
        ////                        // set the swatch into our dictionary and reload the row
        ////                        self?.symbolSwatches[symbol] = image
        ////                        tableView.reloadRows(at: [indexPath], with: .automatic)
        ////                    })
        ////                }
        ////            }
        //        }
        
        return cell
    }
    
    /*
     // Override to support conditional editing of the table view.
     override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the specified item to be editable.
     return true
     }
     */
    
    /*
     // Override to support editing the table view.
     override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
     if editingStyle == .delete {
     // Delete the row from the data source
     tableView.deleteRows(at: [indexPath], with: .fade)
     } else if editingStyle == .insert {
     // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
     }
     }
     */
    
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
    }
    
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return config.allowLayerReordering
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
}
