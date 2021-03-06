#import "BlogListViewController.h"
#import "WordPressAppDelegate.h"
#import "UIImageView+Gravatar.h"
#import "WordPressComApi.h"
#import "LoginViewController.h"
#import "BlogDetailsViewController.h"
#import "WPTableViewCell.h"
#import "WPBlogTableViewCell.h"
#import "ContextManager.h"
#import "Blog.h"
#import "WPAccount.h"
#import "WPTableViewSectionHeaderView.h"
#import "AccountService.h"
#import "BlogService.h"
#import "TodayExtensionService.h"
#import "WPTabBarController.h"
#import "WPFontManager.h"
#import "UILabel+SuggestSize.h"
#import "WordPress-Swift.h"
#import "WPSearchControllerConfigurator.h"

static NSString *const AddSiteCellIdentifier = @"AddSiteCell";
static NSString *const BlogCellIdentifier = @"BlogCell";
static CGFloat const BLVCHeaderViewLabelPadding = 10.0;
static CGFloat const BLVCSectionHeaderHeightForIPad = 40.0;

@interface BlogListViewController () <UIViewControllerRestoration>

@property (nonatomic, strong) NSFetchedResultsController *resultsController;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) WPSearchController *searchController;
@property (nonatomic, strong) IBOutlet UIView *searchWrapperView;
@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *searchWrapperViewHeightConstraint;

@end

@implementation BlogListViewController

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    return [[WPTabBarController sharedInstance] blogListViewController];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.restorationIdentifier = NSStringFromClass([self class]);
        self.restorationClass = [self class];

        // show 'Switch Site' for the next page's back button
        UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Switch Site", @"")
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:nil
                                                                      action:nil];
        [self.navigationItem setBackBarButtonItem:backButton];
        
        UIBarButtonItem *searchButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"icon-post-search"]
                                                                         style:UIBarButtonItemStylePlain
                                                                        target:self
                                                                        action:@selector(toggleSearch)];
        [self.navigationItem setRightBarButtonItem:searchButton];
    }
    return self;
}

- (NSString *)modelIdentifierForElementAtIndexPath:(NSIndexPath *)indexPath inView:(UIView *)view
{
    if (!indexPath || !view) {
        return nil;
    }

    // Preserve objectID
    NSManagedObject *managedObject = [self.resultsController objectAtIndexPath:indexPath];
    return [[managedObject.objectID URIRepresentation] absoluteString];
}

- (NSIndexPath *)indexPathForElementWithModelIdentifier:(NSString *)identifier inView:(UIView *)view
{
    if (!identifier || !view) {
        return nil;
    }

    // Map objectID back to indexPath
    NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
    NSManagedObjectID *objectID = [context.persistentStoreCoordinator managedObjectIDForURIRepresentation:[NSURL URLWithString:identifier]];
    if (!objectID) {
        return nil;
    }

    NSError *error = nil;
    NSManagedObject *managedObject = [context existingObjectWithID:objectID error:&error];
    if (error || !managedObject) {
        return nil;
    }

    NSIndexPath *indexPath = [self.resultsController indexPathForObject:managedObject];

    return indexPath;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Remove one-pixel gap resulting from a top-aligned grouped table view
    if (IS_IPHONE) {
        UIEdgeInsets tableInset = [self.tableView contentInset];
        tableInset.top = -1;
        self.tableView.contentInset = tableInset;
    }

    [WPStyleGuide configureColorsForView:self.view andTableView:self.tableView];
    self.editButtonItem.accessibilityIdentifier = NSLocalizedString(@"Edit", @"");
    
    [self configureTableView];
    [self configureHeaderView];
    [self configureSearchController];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self registerForKeyboardNotifications];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    self.resultsController.delegate = self;
    [self.resultsController performFetch:nil];
    [self.tableView reloadData];
    [self updateEditButton];
    [self maybeShowNUX];
    [self syncBlogs];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.searchController setActive:NO];
    [super viewWillDisappear:animated];
    [self unregisterForKeyboardNotifications];
    self.resultsController.delegate = nil;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    if (self.tableView.tableHeaderView == self.headerView) {
        [self updateHeaderSize];

        // this forces the tableHeaderView to resize
        self.tableView.tableHeaderView = self.headerView;
    }
}

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)unregisterForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardDidShow:(NSNotification *)notification
{
    NSDictionary *info = notification.userInfo;
    CGFloat keyboardHeight = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
    CGFloat tabBarHeight = self.tabBarController.tabBar.bounds.size.height;
    
    UIEdgeInsets newInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardHeight - tabBarHeight, 0.0);
    self.tableView.contentInset = newInsets;
    self.tableView.scrollIndicatorInsets = newInsets;
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    self.tableView.contentInset = UIEdgeInsetsZero;
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

- (NSUInteger)numSites
{
    return [[self.resultsController fetchedObjects] count];
}

- (NSUInteger)numberOfHideableBlogs
{
    NSPredicate *predicate = [self fetchRequestPredicateForHideableBlogs];
    NSArray *dotComSites = [[self.resultsController fetchedObjects] filteredArrayUsingPredicate:predicate];
    return [dotComSites count];
}

- (void)updateEditButton
{
    if ([self numberOfHideableBlogs] > 0) {
        self.navigationItem.leftBarButtonItem = self.editButtonItem;
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }
}

- (void)maybeShowNUX
{
    if ([self numSites] > 0) {
        return;
    }
    NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
    AccountService *accountService = [[AccountService alloc] initWithManagedObjectContext:context];
    WPAccount *defaultAccount = [accountService defaultWordPressComAccount];
    if (!defaultAccount) {
        [WPAnalytics track:WPAnalyticsStatLogout];
        [[WordPressAppDelegate sharedInstance] showWelcomeScreenIfNeededAnimated:YES];
    }
}

- (void)syncBlogs
{
    NSManagedObjectContext *context = [[ContextManager sharedInstance] newDerivedContext];
    [context performBlock:^{
        AccountService *accountService = [[AccountService alloc] initWithManagedObjectContext:context];
        BlogService *blogService = [[BlogService alloc] initWithManagedObjectContext:context];
        WPAccount *defaultAccount = [accountService defaultWordPressComAccount];

        if (defaultAccount) {
            [blogService syncBlogsForAccount:defaultAccount success:nil failure:nil];
        }
    }];
}

#pragma mark - Header methods

- (void)configureHeaderView
{
    self.headerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.headerLabel.numberOfLines = 0;
    self.headerLabel.textAlignment = NSTextAlignmentCenter;
    self.headerLabel.textColor = [WPStyleGuide allTAllShadeGrey];
    self.headerLabel.font = [WPFontManager openSansRegularFontOfSize:14.0];
    self.headerLabel.text = NSLocalizedString(@"Select which sites will be shown in the site picker.", @"Blog list page edit mode header label");
    [self.headerView addSubview:self.headerLabel];
}

- (void)updateHeaderSize
{
    CGFloat labelWidth = CGRectGetWidth(self.view.bounds) - 2 * BLVCHeaderViewLabelPadding;

    CGSize labelSize = [self.headerLabel suggestSizeForString:self.headerLabel.text width:labelWidth];
    self.headerLabel.frame = CGRectMake(BLVCHeaderViewLabelPadding, BLVCHeaderViewLabelPadding, labelWidth, labelSize.height);
    self.headerView.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), labelSize.height + (2 * BLVCHeaderViewLabelPadding));
}

#pragma mark - Public methods

- (BOOL)shouldBypassBlogListViewControllerWhenSelectedFromTabBar
{
    return [self numSites] == 1;
}

- (void)bypassBlogListViewController
{
    if ([self shouldBypassBlogListViewControllerWhenSelectedFromTabBar]) {
        // We do a delay of 0.0 so that way this doesn't kick off until the next run loop.
        [self performSelector:@selector(selectFirstSite) withObject:nil afterDelay:0.0];
    }
}

- (void)selectFirstSite
{
    [self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
}

#pragma mark - Configuration

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)configureTableView
{
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView registerClass:[WPTableViewCell class] forCellReuseIdentifier:AddSiteCellIdentifier];
    [self.tableView registerClass:[WPBlogTableViewCell class] forCellReuseIdentifier:BlogCellIdentifier];
    self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.accessibilityIdentifier = NSLocalizedString(@"Blogs", @"");
}

- (void)configureSearchController
{
    self.searchController = [[WPSearchController alloc] initWithSearchResultsController:nil];
    
    WPSearchControllerConfigurator *searchControllerConfigurator = [[WPSearchControllerConfigurator alloc] initWithSearchController:self.searchController
                                                                                                    withSearchWrapperView:self.searchWrapperView];
    [searchControllerConfigurator configureSearchControllerAndWrapperView];
    [self configureSearchBarPlaceholder];
    self.searchController.delegate = self;
    self.searchController.searchResultsUpdater = self;
}

- (void)configureSearchBarPlaceholder
{
    // Adjust color depending on where the search bar is being presented.
    UIColor *placeholderColor = [WPStyleGuide wordPressBlue];
    NSString *placeholderText = NSLocalizedString(@"Search", @"Placeholder text for the search bar on the post screen.");
    NSAttributedString *attrPlacholderText = [[NSAttributedString alloc] initWithString:placeholderText attributes:[WPStyleGuide defaultSearchBarTextAttributes:placeholderColor]];
    [[UITextField appearanceWhenContainedIn:[UISearchBar class], [self class], nil] setAttributedPlaceholder:attrPlacholderText];
    [[UITextField appearanceWhenContainedIn:[UISearchBar class], [self class], nil] setDefaultTextAttributes:[WPStyleGuide defaultSearchBarTextAttributes:[UIColor whiteColor]]];
}

- (CGFloat)heightForSearchWrapperView
{
    if ([UIDevice isPad]) {
        return SearchWrapperViewPortraitHeight;
    }
    return UIDeviceOrientationIsPortrait(self.interfaceOrientation) ? SearchWrapperViewPortraitHeight : SearchWrapperViewLandscapeHeight;
}

#pragma mark - Notifications

- (void)wordPressComApiDidLogin:(NSNotification *)notification
{
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)wordPressComApiDidLogout:(NSNotification *)notification
{
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.tableView.isEditing || [self.searchController isActive]) { // Don't show "Add Site"
        return 1;
    } else {
        return 2;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id<NSFetchedResultsSectionInfo> sectionInfo;
    NSInteger numberOfRows = 0;
    if ([self.resultsController sections].count > section) {
        sectionInfo = [[self.resultsController sections] objectAtIndex:section];
        numberOfRows = sectionInfo.numberOfObjects;
    } else {
        // This is for the "Add a Site" row
        numberOfRows = 1;
    }

    return numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    if ([indexPath isEqual:[self indexPathForAddSite]]) {
        cell = [self.tableView dequeueReusableCellWithIdentifier:AddSiteCellIdentifier];
    } else {
        cell = [self.tableView dequeueReusableCellWithIdentifier:BlogCellIdentifier];
    }

    [self configureCell:cell atIndexPath:indexPath];

    if ([indexPath isEqual:[self indexPathForAddSite]]) {
        [WPStyleGuide configureTableViewActionCell:cell];
    } else {
        [WPStyleGuide configureTableViewSmallSubtitleCell:cell];
    }

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NSLocalizedString(@"Remove", @"Button label when removing a blog");
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (NSIndexPath *)indexPathForAddSite
{
    return [NSIndexPath indexPathForRow:0 inSection:1];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.imageView.image = nil;

    if ([indexPath isEqual:[self indexPathForAddSite]]) {
        cell.textLabel.text = NSLocalizedString(@"Add a Site", @"");
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
    } else {
        Blog *blog = [self.resultsController objectAtIndexPath:indexPath];
        if ([blog.blogName length] != 0) {
            cell.textLabel.text = blog.blogName;
            cell.detailTextLabel.text = [blog displayURL];
        } else {
            cell.textLabel.text = [blog displayURL];
            cell.detailTextLabel.text = @"";
        }

        [cell.imageView setImageWithSiteIcon:blog.icon];
        if ([self.tableView isEditing] && [blog supports:BlogFeatureVisibility]) {
            UISwitch *visibilitySwitch = [UISwitch new];
            visibilitySwitch.on = blog.visible;
            visibilitySwitch.tag = indexPath.row;
            [visibilitySwitch addTarget:self action:@selector(visibilitySwitchAction:) forControlEvents:UIControlEventValueChanged];
            visibilitySwitch.accessibilityIdentifier = [NSString stringWithFormat:@"Switch-Visibility-%@", blog.blogName];
            cell.accessoryView = visibilitySwitch;

            // Make textLabel light gray if blog is not-visible
            if (!visibilitySwitch.on) {
                [cell.textLabel setTextColor:[WPStyleGuide readGrey]];
            }

        } else {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.selectionStyle = self.tableView.isEditing ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleBlue;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSString *title = [self tableView:self.tableView titleForHeaderInSection:section];
    if (title.length > 0) {
        WPTableViewSectionHeaderView *header = [[WPTableViewSectionHeaderView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 0)];
        header.title = title;
        return header;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSString *title = [self tableView:self.tableView titleForHeaderInSection:section];
    if (title.length > 0) {
        return [WPTableViewSectionHeaderView heightForTitle:title andWidth:CGRectGetWidth(self.view.bounds)];
    }
    // since we show a tableHeaderView while editing, we want to keep the section header short for iPad during edit
    return (IS_IPHONE || self.tableView.isEditing) ? CGFLOAT_MIN : BLVCSectionHeaderHeightForIPad;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    // Use the standard dimension on the last section
    return section == [tableView numberOfSections] - 1 ? UITableViewAutomaticDimension : 0.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if ([indexPath isEqual:[self indexPathForAddSite]]) {
        [self setEditing:NO animated:NO];
        LoginViewController *loginViewController = [[LoginViewController alloc] init];
        loginViewController.cancellable = YES;

        NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
        AccountService *accountService = [[AccountService alloc] initWithManagedObjectContext:context];
        WPAccount *defaultAccount = [accountService defaultWordPressComAccount];

        if (!defaultAccount) {
            loginViewController.prefersSelfHosted = YES;
        }
        loginViewController.dismissBlock = ^(BOOL cancelled){
            [self dismissViewControllerAnimated:YES completion:nil];
        };
        UINavigationController *loginNavigationController = [[UINavigationController alloc] initWithRootViewController:loginViewController];
        [self presentViewController:loginNavigationController animated:YES completion:nil];
    } else if (self.tableView.isEditing) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        UISwitch *visibleSwitch = (UISwitch *)cell.accessoryView;
        if (visibleSwitch && [visibleSwitch isKindOfClass:[UISwitch class]]) {
            visibleSwitch.on = !visibleSwitch.on;
            [self visibilitySwitchAction:visibleSwitch];
        }
        return;
    } else {
        NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
        BlogService *blogService = [[BlogService alloc] initWithManagedObjectContext:context];
        Blog *blog = [self.resultsController objectAtIndexPath:indexPath];
        blog.visible = YES;
        [blogService flagBlogAsLastUsed:blog];

        BlogDetailsViewController *blogDetailsViewController = [[BlogDetailsViewController alloc] init];
        blogDetailsViewController.blog = blog;
        [self.navigationController pushViewController:blogDetailsViewController animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 54;
}

# pragma mark - WPSeachController delegate methods

- (void)presentSearchController:(WPSearchController *)searchController
{
    [self.navigationController setNavigationBarHidden:YES animated:YES]; // Remove this line when switching to UISearchController.
    self.searchWrapperViewHeightConstraint.constant = [self heightForSearchWrapperView];
    [UIView animateWithDuration:SearchBarAnimationDuration
                          delay:0.0
                        options:0
                     animations:^{
                         [self.view layoutIfNeeded];
                     } completion:^(BOOL finished) {
                         [self.searchController.searchBar becomeFirstResponder];
                     }];
}

- (void)willDismissSearchController:(WPSearchController *)searchController
{
    [self.searchController.searchBar resignFirstResponder];
    [self.navigationController setNavigationBarHidden:NO animated:YES]; // Remove this line when switching to UISearchController.
    self.searchWrapperViewHeightConstraint.constant = 0;
    [UIView animateWithDuration:SearchBarAnimationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
    
    self.searchController.searchBar.text = nil;
}

- (void)updateSearchResultsForSearchController:(WPSearchController *)searchController
{
    [self updateFetchRequest];
}

# pragma mark - Navigation Bar

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
    self.navigationItem.rightBarButtonItem.enabled = !editing;

    if (editing) {
        [self updateHeaderSize];
        self.tableView.tableHeaderView = self.headerView;
    }
    else {
        // setting the table header view to nil creates extra space, empty view is a way around that
        self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, CGFLOAT_MIN)];
    }

    // Animate view to editing mode
    __block UIView *snapshot;
    if (animated) {
        snapshot = [self.view snapshotViewAfterScreenUpdates:NO];
        snapshot.frame = [self.view convertRect:self.view.frame fromView:self.view.superview];
        [self.view addSubview:snapshot];
    }

    // Update results controller to show hidden blogs
    [self updateFetchRequest];

    if (animated) {
        [UIView animateWithDuration:0.2 animations:^{
            snapshot.alpha = 0.0;
        } completion:^(BOOL finished) {
            [snapshot removeFromSuperview];
            snapshot = nil;
        }];
    }
}

- (void)toggleSearch
{
    self.searchController.active = !self.searchController.active;
}

- (void)visibilitySwitchAction:(id)sender
{
    UISwitch *switcher = (UISwitch *)sender;
    Blog *blog = [self.resultsController objectAtIndexPath:[NSIndexPath indexPathForRow:switcher.tag inSection:0]];
    if (switcher.on != blog.visible) {
        blog.visible = switcher.on;
        [[ContextManager sharedInstance] saveContext:blog.managedObjectContext];
    }
}

#pragma mark - NSFetchedResultsController

- (NSFetchedResultsController *)resultsController
{
    if (_resultsController) {
        return _resultsController;
    }

    NSManagedObjectContext *moc = [[ContextManager sharedInstance] mainContext];
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Blog"];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"blogName" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]]];
    [fetchRequest setPredicate:[self fetchRequestPredicate]];

    _resultsController = [[NSFetchedResultsController alloc]
                          initWithFetchRequest:fetchRequest
                          managedObjectContext:moc
                          sectionNameKeyPath:nil
                          cacheName:nil];
    _resultsController.delegate = self;

    NSError *error = nil;
    if (![_resultsController performFetch:&error]) {
        DDLogError(@"Couldn't fetch sites: %@", [error localizedDescription]);
        _resultsController = nil;
    }
    return _resultsController;
}

- (NSPredicate *)fetchRequestPredicate
{
    if ([self.tableView isEditing]) {
        return [self fetchRequestPredicateForHideableBlogs];
    } else if ([self.searchController isActive]) {
        return [self fetchRequestPredicateForSearch];
    }

    return [NSPredicate predicateWithFormat:@"visible = YES"];
}

- (NSPredicate *)fetchRequestPredicateForSearch
{
    NSString *searchText = self.searchController.searchBar.text;
    
    if ([searchText isEmpty]) {
        return [self fetchRequestPredicateForHideableBlogs];
    } else {
        return [NSPredicate predicateWithFormat:@"( blogName contains[cd] %@ ) OR ( url contains[cd] %@)", searchText, searchText];
    }
}

- (NSPredicate *)fetchRequestPredicateForHideableBlogs
{
    /*
     -[Blog supports:BlogFeatureVisibility] should match this, but the logic needs
     to be duplicated because core data can't take block predicates.
     */
    NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
    AccountService *accountService = [[AccountService alloc] initWithManagedObjectContext:context];
    WPAccount *defaultAccount = [accountService defaultWordPressComAccount];

    return [NSPredicate predicateWithFormat:@"account != NULL AND account = %@", defaultAccount];
}

- (void)updateFetchRequest
{
    self.resultsController.fetchRequest.predicate = [self fetchRequestPredicate];

    NSError *error = nil;
    if (![self.resultsController performFetch:&error]) {
        DDLogError(@"Couldn't fetch sites: %@", [error localizedDescription]);
    }

    [self.tableView reloadData];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView reloadData];
    [self updateEditButton];
    [self maybeShowNUX];
}

@end
