//
//  RAPFavoritesViewController.m
//  redditAPI
//
//  Created by Woudini on 2/3/15.
//  Copyright (c) 2015 Hi Range. All rights reserved.
//

#import "RAPFavoritesViewController.h"
#import "ViewController.h"
#import "RAPRectangleSelector.h"
#import "RAPFavoritesDataSource.h"

#define RAPSegueNotification @"RAPSegueNotification"

@interface RAPTiltToScrollViewController()
-(void)createTableViewCellRectWithCellRect:(CGRect)cellRect;
-(void)stopTiltToScrollAndRemoveRectSelector;
@end

@interface RAPFavoritesViewController ()
@property (nonatomic) NSMutableArray *favoritesMutableArray;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) RAPTiltToScroll *tiltToScroll;
@property (nonatomic) CGRect tableViewCellRect;
@property (nonatomic) RAPRectangleSelector *rectangleSelector;
@property (nonatomic) RAPFavoritesDataSource *dataSource;
@end

@implementation RAPFavoritesViewController

-(RAPTiltToScroll *)tiltToScroll
{
    if (!_tiltToScroll) _tiltToScroll = [[RAPTiltToScroll alloc] init];
    return _tiltToScroll;
}

#pragma mark Segue methods

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"subredditSegue"])
    {
        NSIndexPath *indexPath;
        if (![self.tableView indexPathForSelectedRow])
        {
            indexPath = [self.tableView indexPathForCell:[[self.tableView visibleCells] objectAtIndex:super.rectangleSelector.cellIndex]];
            NSLog(@"Indexpath.row is %d", indexPath.row);
        }
        else // Otherwise, the user has tapped the row, so use the row that was tapped
        {
            indexPath = [self.tableView indexPathForSelectedRow];
            [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
        }
        
        RAPViewController *subredditViewController = segue.destinationViewController;
        NSString *subredditString = self.favoritesMutableArray[indexPath.row];
        subredditViewController.subRedditURLString = subredditString;
    }
}

-(void)segueWhenSelectedRow
{
    if (super.rectangleSelector.cellIndex != super.rectangleSelector.cellMax && [self.tableView indexPathForSelectedRow].row != super.rectangleSelector.cellMax)
    {
        [self performSegueWithIdentifier:@"subredditSegue" sender:nil];
    }
}

#pragma mark Adding subreddits

- (IBAction)addFavoriteButtonTapped:(UIBarButtonItem *)sender
{
    [self addSubreddit];
}

-(void)addSubreddit
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Add subreddit" message:@"reddit.com/r/" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Add", nil];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    alertView.tag = 100;
    [alertView show];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (alertView.tag)
    {
        case 100:
        {
            if (buttonIndex == 1)
            {
                UITextField *subredditToAddTextField = [alertView textFieldAtIndex:0];
                NSString *subredditToAddString = [subredditToAddTextField.text lowercaseString];
                if (subredditToAddString.length > 0)
                {
                    [self verifySubredditWithString:subredditToAddString];
                }
                else
                {
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Blank entry" message:@"Please enter a subreddit" delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                    alertView.tag = 101;
                    [alertView show];
                }
            }
            break;
        }
        case 101:
        {
            [self addSubreddit];
            break;
        }
        case 404:
        {
            [self addSubreddit];
            break;
        }
    }
}

-(void)alertUserThatSubredditCannotBeFound
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Invalid subreddit" message:@"Please enter a valid subreddit" delegate:self cancelButtonTitle:nil otherButtonTitles: @"OK", nil];
    alertView.tag = 404;
    [alertView show];
}

-(void)verifySubredditWithString:(NSString *)appendString
{
    NSURL *url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"http://www.reddit.com/r/%@/.json", appendString]];
    NSURLSessionConfiguration *sessionconfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionconfig];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
                                      {
                                          NSMutableDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                                          NSSet *jsonResults = [[NSSet alloc] initWithArray:[jsonData[@"data"] objectForKey:@"children"]];
                                          //NSLog(@"Subreddit is %@", jsonData);
                                          
                                          dispatch_async(dispatch_get_main_queue(), ^
                                                         {
                                                             if ([jsonResults count] == 0)
                                                             {
                                                                 NSLog(@"subreddit not found");
                                                                 [self alertUserThatSubredditCannotBeFound];
                                                             }
                                                             else
                                                             {
                                                                 [self.favoritesMutableArray addObject:appendString];
                                                                 [self.favoritesMutableArray sortUsingSelector:@selector(localizedCompare:)];
                                                                 NSIndexPath *indexPathForWord = [NSIndexPath indexPathForRow:[self.favoritesMutableArray indexOfObject:appendString] inSection:self.tableView.numberOfSections-1];
                                                                 [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPathForWord] withRowAnimation:UITableViewRowAnimationFade];
                                                                 [self updateFavorites];
                                                                 [self.tableView reloadData];
                                                             }
                                                             
                                                         });
                                      }];
    
    [dataTask resume];
}

#pragma mark Table View Methods

- (void)setupDataSource
{
    void (^deleteCell)(NSIndexPath*) = ^(NSIndexPath *indexPath) {
        [self.favoritesMutableArray removeObjectAtIndex:indexPath.row];
        [self updateFavorites];
    };
    
    self.dataSource = [[RAPFavoritesDataSource alloc] initWithItems:self.favoritesMutableArray cellIdentifier:@"favoritesCell" deleteCellBlock:deleteCell];
    
    self.tableView.dataSource = self.dataSource;
    self.tableView.delegate = self.dataSource;
}

#pragma mark Favorites methods

-(void)updateFavorites
{
    [[NSUserDefaults standardUserDefaults] setValue:self.favoritesMutableArray forKey:@"favorites"];
}

-(NSArray *)defaultSubredditFavorites
{
    return @[@"adviceanimals",@"announcements",@"askreddit",@"aww",@"blog",@"funny",@"gaming",@"iama",@"pics",@"politics",@"programming",@"science",@"technology",@"todayilearned",@"worldnews"];
}

#pragma mark View methods

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    NSDictionary *defaultFavorites = [NSDictionary dictionaryWithObject:[self defaultSubredditFavorites] forKey:@"favorites"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultFavorites];
    
    self.favoritesMutableArray = [[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] valueForKey:@"favorites"]];
    
    [self setupDataSource];
    // Dou any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(segueWhenSelectedRow) name:RAPSegueNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

@end
