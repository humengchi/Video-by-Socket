//
//  CameraViewController.h
//  Coordinate
//
//  Created by hmc on 24/11/14.
//  Copyright (c) 2014年 Corrine Chan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AsyncUdpSocket.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#define MAXSEND (1024*8)
@interface CameraViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>
{
    
}
@property (strong, nonatomic) IBOutlet UIImageView  *myselfImage;
@property (strong, nonatomic) IBOutlet UIImageView  *otherImage;
@property (strong, nonatomic) IBOutlet UITableView  *myTableView;

@property (strong, nonatomic) IBOutlet UILabel      *speedLabel;
@property (strong, nonatomic) IBOutlet UILabel      *psLabel;
@property (nonatomic, retain) AsyncUdpSocket        *udpSocket;
@property (nonatomic, retain) NSString              *myIP;
@property (strong, nonatomic) NSMutableData         *receiveData;
@property (strong, nonatomic) NSMutableData         *sendData;

@property (strong, nonatomic) NSMutableData         *allNumber;
@property (strong, nonatomic) NSMutableData         *everyNumber;
@property (strong, nonatomic) NSMutableData         *timeData;

@property (strong, nonatomic) NSMutableData         *receiveData1;
@property (strong, nonatomic) NSMutableData         *receiveData2;
@property (strong, nonatomic) NSMutableData         *receiveData3;
@property (strong, nonatomic) NSMutableData         *receiveData4;
@property (strong, nonatomic) NSMutableData         *receiveData5;
@property (strong, nonatomic) NSMutableData         *receiveData6;
@property (strong, nonatomic) NSMutableData         *receiveData7;
@property (strong, nonatomic) NSMutableData         *receiveData8;
@property (strong, nonatomic) NSMutableData         *receiveData9;

@property (strong, nonatomic) NSMutableArray        *tableArray;


@end
