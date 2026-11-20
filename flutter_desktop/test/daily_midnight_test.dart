import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/order_reporting.dart';
import 'package:nohut_falafel_desktop/operations.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';

Map<String,dynamic> datedOrder(int id, String createdAt) => {
  'id':id,
  'source':'Gel-Al',
  'createdAt':createdAt,
  'closed':true,
  'cancelled':false,
  'batches':[{
    'id':1,
    'staff':'Kasa (PC)',
    'createdAt':createdAt,
    'lines':[{
      'productId':0,'name':'Falafel Dürüm','price':140,'qty':1,
    }],
  }],
  'payments':[],
};

void main() {
  test('Turkish business day changes at exact 00:00 Europe/Istanbul', () {
    const before='2026-11-14T20:59:59Z';
    const after='2026-11-14T21:00:00Z';
    expect(istanbulDay(DateTime.parse(before)),'2026-11-14');
    expect(istanbulDay(DateTime.parse(after)),'2026-11-15');
    expect(onIstanbulDay(before,'2026-11-14'),isTrue);
    expect(onIstanbulDay(before,'2026-11-15'),isFalse);
    expect(onIstanbulDay(after,'2026-11-15'),isTrue);
    expect(onIstanbulDay(null,'2026-11-15'),isFalse);
  });

  test('next Turkish midnight independent of desktop system timezone', () {
    expect(
      nextIstanbulMidnightUtc(DateTime.parse('2026-11-14T20:59:59Z')),
      DateTime.utc(2026,11,14,21),
    );
    expect(
      nextIstanbulMidnightUtc(DateTime.parse('2026-11-14T21:00:00Z')),
      DateTime.utc(2026,11,15,21),
    );
    expect(
      nextIstanbulMidnightUtc(DateTime.parse('2026-12-31T20:59:59Z')),
      DateTime.utc(2026,12,31,21),
    );
  });

  test('daily invoice display starts 0001 again, never resets unique SQLite IDs', () {
    final db=emptyPosState();
    db['orders']=[
      datedOrder(1200,'2026-11-14T20:59:59Z'),
      datedOrder(1201,'2026-11-14T21:00:00Z'),
      datedOrder(1202,'2026-11-14T21:15:00Z'),
    ];
    db['nextId']=1203;
    assignDailyNumbers(db);
    final orders=(db['orders'] as List).cast<Map>();
    expect(orders.map((o)=>o['dailyNumber']).toList(),[1,1,2]);
    expect(orders.map(displayOrderNumber).toList(),['0001','0001','0002']);
    expect(orders.map((o)=>o['numberDay']).toList(),[
      '2026-11-14','2026-11-15','2026-11-15',
    ]);
    expect(db['nextId'],1203);
    assignDailyNumbers(db); // an app restart must NOT renumber receipts
    expect(orders.map(displayOrderNumber).toList(),['0001','0001','0002']);
    expect(db['orders'],hasLength(3));
  });

  test('one daily POS sequence for Masa, Trendyol Go and Gel-Al', () {
    final db = emptyPosState();
    final masa = datedOrder(1200, '2026-11-15T11:00:00Z');
    masa['source'] = 'Masa';
    masa['table'] = 1;
    db['orders'] = [masa];
    assignDailyNumbers(db);
    expect(displayOrderNumber(masa), '0001');

    final trendyol = <String, dynamic>{
      'source': 'Trendyol Go',
      'orderNumber': 'PLATFORM-999',
      'createdAt': '2026-11-15T11:01:00Z',
      'status': 'Picking',
    };
    db['trendyolGoOrders'] = [trendyol];
    assignDailyNumbers(db);
    expect(displayOrderNumber(trendyol), '0002');
    expect(trendyol['orderNumber'], 'PLATFORM-999');

    final gelAl = datedOrder(1201, '2026-11-15T11:02:00Z');
    (db['orders'] as List).add(gelAl);
    assignDailyNumbers(db);
    expect(displayOrderNumber(gelAl), '0003');
    final orders = (db['orders'] as List).cast<Map>();
    expect(orders.map(displayOrderNumber).toList(), ['0001', '0003']);

    trendyol['status'] = 'Delivered';
    assignDailyNumbers(db);
    expect(displayOrderNumber(trendyol), '0002');
    expect(displayOrderNumber(gelAl), '0003');

    final nextDay = datedOrder(1202, '2026-11-15T21:00:00Z');
    (db['orders'] as List).add(nextDay);
    assignDailyNumbers(db);
    expect(displayOrderNumber(nextDay), '0001');
    expect(trendyol['numberDay'], '2026-11-15');
    expect(nextDay['numberDay'], '2026-11-16');
  });

  test('today order counts ignore last night, preserve yesterday in history', () {
    final orders=[
      datedOrder(1200,'2026-11-14T20:59:59Z'),
      datedOrder(1201,'2026-11-14T21:00:00Z'),
    ];
    final today='2026-11-15';
    final count=orders.where((o)=>onIstanbulDay(o['createdAt'],today)).length;
    expect(count,1);
    expect(orders,hasLength(2));
    final buckets=hourlyOrderCounts(orders,from:today,to:today);
    expect(buckets[0],1);
    expect(buckets.reduce((a,b)=>a+b),1);
    final oldBuckets=hourlyOrderCounts(
      orders,from:'2026-11-14',to:'2026-11-14',
    );
    expect(oldBuckets[23],1);
  });

  test('a payment on yesterday order counts toward NEW business day only', () {
    final db=emptyPosState();
    final order=datedOrder(1200,'2026-11-14T20:58:59Z');
    order['payments']=[
      {
        'method':'Nakit','amount':140,'by':'Kasa (PC)',
        'createdAt':'2026-11-14T21:00:00Z',
        'refunds':[],
      },
    ];
    db['orders']=[order];
    final rows=ledger(db);
    expect(rows,hasLength(1));
    expect(
      rows.where((e)=>onIstanbulDay(e.stamp,'2026-11-14'))
        .fold<int>(0,(sum,e)=>sum+e.amount),
      0,
    );
    expect(
      rows.where((e)=>onIstanbulDay(e.stamp,'2026-11-15'))
        .fold<int>(0,(sum,e)=>sum+e.amount),
      14000,
    );
    expect((db['orders'] as List),hasLength(1));
    expect((order['payments'] as List),hasLength(1));
  });
}
