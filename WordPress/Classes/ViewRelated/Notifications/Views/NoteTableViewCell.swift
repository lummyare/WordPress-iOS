import Foundation


/**
*  @class       NoteTableViewCell
*  @brief       The purpose of this class is to render a Notification entity, onscreen.
*  @details     This cell should be loaded from its nib, since the autolayout constraints and outlets are not
*               generated via code.
*               Supports specific styles for Unapproved Comment Notifications, Unread Notifications, and a brand
*               new "Undo Deletion" mechanism has been implemented. See "NoteUndoOverlayView" for reference.
*/

@objc public class NoteTableViewCell : WPTableViewCell
{
    // MARK: - Public Properties
    public var read: Bool = false {
        didSet {
            if read != oldValue {
                refreshBackgrounds()
            }
        }
    }
    public var unapproved: Bool = false {
        didSet {
            if unapproved != oldValue {
                refreshBackgrounds()
            }
        }
    }
    public var markedForDeletion: Bool = false {
        didSet {
            if markedForDeletion != oldValue {
                refreshSubviewVisibility()
                refreshBackgrounds()
                refreshUndoOverlay()
            }
        }
    }
    public var showsBottomSeparator: Bool {
        set {
            separatorsView.bottomVisible = newValue
        }
        get {
            return separatorsView.bottomVisible == false
        }
    }
    public var attributedSubject: NSAttributedString? {
        set {
            subjectLabel.attributedText = newValue
            setNeedsLayout()
        }
        get {
            return subjectLabel.attributedText
        }
    }
    public var attributedSnippet: NSAttributedString? {
        set {
            snippetLabel.attributedText = newValue
            refreshNumberOfLines()
            setNeedsLayout()
        }
        get {
            return snippetLabel.attributedText
        }
    }
    public var noticon: String? {
        set {
            noticonLabel.text = newValue
        }
        get {
            return noticonLabel.text
        }
    }
    public var onUndelete: (Void -> Void)?
    
    
    
    // MARK: - Public Methods
    public class func reuseIdentifier() -> String {
        return classNameWithoutNamespaces()
    }
    
    public func downloadGravatarWithURL(url: NSURL?) {
        if url == gravatarURL {
            return
        }

        let placeholderImage = WPStyleGuide.Notifications.gravatarPlaceholderImage
        
        // Scale down Gravatar images: faster downloads!
        if let unrawppedURL = url {
            let size                = iconImageView.frame.width * UIScreen.mainScreen().scale
            let scaledURL           = unrawppedURL.patchGravatarUrlWithSize(size)
            iconImageView.downloadImage(scaledURL, placeholderImage: placeholderImage)
        } else {
            iconImageView.image     = placeholderImage
        }
        
        gravatarURL = url
    }
 
    
    
    // MARK: - UITableViewCell Methods
    public override func awakeFromNib() {
        super.awakeFromNib()

        contentView.autoresizingMask    = .FlexibleHeight | .FlexibleWidth

        iconImageView.image             = WPStyleGuide.Notifications.gravatarPlaceholderImage

        noticonContainerView.layer.cornerRadius = noticonContainerView.frame.size.width / 2

        noticonView.layer.cornerRadius  = Settings.noticonRadius
        noticonLabel.font               = Style.noticonFont
        noticonLabel.textColor          = Style.noticonTextColor
        
        subjectLabel.numberOfLines      = Settings.subjectNumberOfLinesWithSnippet
        subjectLabel.shadowOffset       = CGSizeZero

        snippetLabel.numberOfLines      = Settings.snippetNumberOfLines
        
        // Separators: Setup bottom separators!
        separatorsView.bottomColor      = WPStyleGuide.Notifications.noteSeparatorColor
        separatorsView.bottomInsets     = Settings.separatorInsets
        backgroundView                  = separatorsView
    }
    
    public override func layoutSubviews() {
        refreshLabelPreferredMaxLayoutWidth()
        refreshBackgrounds()
        super.layoutSubviews()
    }

    public override func setSelected(selected: Bool, animated: Bool) {
        // Note: this is required, since the cell unhighlight mechanism will reset the new background color
        super.setSelected(selected, animated: animated)
        refreshBackgrounds()
    }
    
    public override func setHighlighted(highlighted: Bool, animated: Bool) {
        // Note: this is required, since the cell unhighlight mechanism will reset the new background color
        super.setHighlighted(highlighted, animated: animated)
        refreshBackgrounds()
    }
    
    
    
    // MARK: - Private Methods
    private func refreshLabelPreferredMaxLayoutWidth() {
        let maxWidthLabel                    = frame.width - Settings.textInsets.right - subjectLabel.frame.minX
        subjectLabel.preferredMaxLayoutWidth = maxWidthLabel
        snippetLabel.preferredMaxLayoutWidth = maxWidthLabel
    }
    
    private func refreshBackgrounds() {
        // Noticon Background
        if unapproved {
            noticonView.backgroundColor             = Style.noticonUnmoderatedColor
            noticonContainerView.backgroundColor    = Style.noticonTextColor
        } else if read {
            noticonView.backgroundColor             = Style.noticonReadColor
            noticonContainerView.backgroundColor    = Style.noticonTextColor
        } else {
            noticonView.backgroundColor             = Style.noticonUnreadColor
            noticonContainerView.backgroundColor    = Style.noteBackgroundUnreadColor
        }

        // Cell Background: Assign only if needed, for performance
        let newBackgroundColor = read ? Style.noteBackgroundReadColor : Style.noteBackgroundUnreadColor

        if backgroundColor != newBackgroundColor {
            backgroundColor = newBackgroundColor
        }
    }
    
    private func refreshSubviewVisibility() {
        for subview in contentView.subviews as! [UIView] {
            subview.hidden = markedForDeletion
        }
    }
    
    private func refreshNumberOfLines() {
        // When the snippet is present, let's clip the number of lines in the subject
        let showsSnippet = attributedSnippet != nil
        subjectLabel.numberOfLines =  Settings.subjectNumberOfLines(showsSnippet)
    }
    
    private func refreshUndoOverlay() {
        // Remove
        if markedForDeletion == false {
            undoOverlayView?.removeFromSuperview()
            return
        }
        
        // Load
        if undoOverlayView == nil {
            let nibName = NoteUndoOverlayView.classNameWithoutNamespaces()
            NSBundle.mainBundle().loadNibNamed(nibName, owner: self, options: nil)
            undoOverlayView.setTranslatesAutoresizingMaskIntoConstraints(false)
        }

        // Attach
        if undoOverlayView.superview == nil {
            contentView.addSubview(undoOverlayView)
            contentView.pinSubviewToAllEdges(undoOverlayView)
        }
    }

    
    
    // MARK: - Public Static Helpers
    public class func layoutHeightWithWidth(width: CGFloat, subject: NSAttributedString?, snippet: NSAttributedString?) -> CGFloat {
        
        // Limit the width (iPad Devices)
        let cellWidth               = min(width, Style.maximumCellWidth)
        var cellHeight              = Settings.textInsets.top + Settings.textInsets.bottom
        
        // Calculate the maximum label size
        let maxLabelWidth           = cellWidth - Settings.textInsets.left - Settings.textInsets.right
        let maxLabelSize            = CGSize(width: maxLabelWidth, height: CGFloat.max)
        
        // Helpers
        let showsSnippet            = snippet != nil
        
        // If we must render a snippet, the maximum subject height will change. Account for that please
        if let unwrappedSubject = subject {
            let subjectRect         = unwrappedSubject.boundingRectWithSize(maxLabelSize,
                                        options: .UsesLineFragmentOrigin,
                                        context: nil)
            
            cellHeight              += min(subjectRect.height, Settings.subjectMaximumHeight(showsSnippet))
        }
        
        if let unwrappedSubject = snippet {
            let snippetRect         = unwrappedSubject.boundingRectWithSize(maxLabelSize,
                                        options: .UsesLineFragmentOrigin,
                                        context: nil)
            
            cellHeight              += min(snippetRect.height, Settings.snippetMaximumHeight())
        }
        
        return max(cellHeight, Settings.minimumCellHeight)
    }
    
    
    
    // MARK: - Action Handlers
    @IBAction public func undeleteWasPressed(sender: AnyObject) {
        if let handler = onUndelete {
            handler()
        }
    }
    
    
    
    // MARK: - Private Alias
    private typealias Style = WPStyleGuide.Notifications
    
    // MARK: - Private Settings
    private struct Settings {
        static let minimumCellHeight                    = CGFloat(70)
        static let textInsets                           = UIEdgeInsets(top: 9.0, left: 71.0, bottom: 12.0, right: 12.0)
        static let separatorInsets                      = UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 0.0)
        static let subjectNumberOfLinesWithoutSnippet   = 3
        static let subjectNumberOfLinesWithSnippet      = 2
        static let snippetNumberOfLines                 = 2
        static let noticonRadius                        = CGFloat(10)
        
        static func subjectNumberOfLines(showsSnippet: Bool) -> Int {
            return showsSnippet ? subjectNumberOfLinesWithSnippet : subjectNumberOfLinesWithoutSnippet
        }

        static func subjectMaximumHeight(showsSnippet: Bool) -> CGFloat {
            return CGFloat(Settings.subjectNumberOfLines(showsSnippet)) * Style.subjectLineSize
        }
        
        static func snippetMaximumHeight() -> CGFloat {
            return CGFloat(snippetNumberOfLines) * Style.snippetLineSize
        }
    }

    // MARK: - Private Properties
    private var gravatarURL : NSURL?
    private var separatorsView = NoteSeparatorsView()
    
    // MARK: - IBOutlets
    @IBOutlet private weak var iconImageView:           CircularImageView!
    @IBOutlet private weak var noticonLabel:            UILabel!
    @IBOutlet private weak var noticonContainerView:    UIView!
    @IBOutlet private weak var noticonView:             UIView!
    @IBOutlet private weak var subjectLabel:            UILabel!
    @IBOutlet private weak var snippetLabel:            UILabel!
    @IBOutlet private weak var timestampLabel:          UILabel!
    
    // MARK: - Undo Overlay Optional
    @IBOutlet private var undoOverlayView:              NoteUndoOverlayView!
}
