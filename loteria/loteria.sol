// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts@4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.5.0/access/Ownable.sol";

contract loteria is ERC20, Ownable {
    //=====================================================
    // Gestion de los tokens 
    //======================================================

    // direccion 
    address public nft;

    //contructor
    constructor() ERC20("Loteria", "JA"){
        _mint(address(this), 1000);
        nft = address(new mainERC721());
    }

    //ganador del premio de la loteria
    address public ganador;

    //registro del usuario 
    mapping(address => address) public usuario_contracto;
    
    //precio de los tokens
    function precioTokens(uint _mounToken) internal pure returns (uint){
        return _mounToken*(1 ether);        
    }

    // visualizacion del valance de tokens ERC20 de un usuario
    function balanceTokens(address _account) public view returns(uint){
        return balanceOf(_account);
    }

    //visualiza del balance de ethers del smart contract 
    function balanceEtherSc() public view returns (uint){
        return address(this).balance/10**18;
    }

    // generacion de nuevos tokens de ERC-20 
    function mint(uint _cantidad) public onlyOwner {
        _mint(address(this), _cantidad);
    }

    //registro de un usuario
    function registrar() internal {
        address add_personal_contract = address(new boletosNFTs(msg.sender, address(this), nft));
         usuario_contracto[msg.sender] = add_personal_contract;
    }

    // Informacion de un usuario
    function usersInfo(address _Account) public view returns(address) {
        return usuario_contracto[_Account];
    }

    // compra de tokens ERC-20
    function compraTokens(uint _numTokens) public payable {
        if(usuario_contracto[msg.sender] == address(0)){
            registrar();
        }
        // establecimiento del coste de los tokens a comprar
        uint coste = precioTokens(_numTokens);
        //Evaluar del dinero que el cliente paga por los tokens
        require(msg.value >= coste, "Compra menos tokens o paga con mas ethers");
        // obtencion del numero de tokens ERC-20 disponibles
        uint balance = balanceEtherSc();
        require(_numTokens <= balance, "compra un numero menor de tokens");
        // devolucion del dinero sobrantes
        uint returnValue = msg.value - coste;
        // EL smart contract devuelve la cantidad restante
        payable(msg.sender).transfer(returnValue);//evio de ethres
        // envio de los tokens al cliente/usuario
        _transfer(address(this), msg.sender, _numTokens);// envio de tokens
    }

    //devlover tokensal smart contract
    function devolverTokens(uint _numTokens) public payable {
       // el numero de tokens debe de mayor a 0
        require(_numTokens > 0, "Necesitas devolver un numero de tokens mayor a 0");
        // El Usuario debe acreditar tenerlos tokens que quiere devolver
        require(_numTokens <= balanceTokens(msg.sender), "No tienes los tokens que deseas devolver");
        // El usuario trasnfiere los tokens al smart contract 
        payable(msg.sender).transfer(precioTokens(_numTokens));
    }


    //=======================================================
    // Gestion de la loteria
    //=======================================================
    // precio del boletos (ERC-20)
    uint public precioBoleto = 5;
    // Relacion: Persona que compra los boletos = el numero de los boletos 
    mapping(address => uint[]) idPersona_boletos;
    // relacion: boletos -> ganador
    mapping(uint => address ) ADNBoletos;
    // numero aleatorio
    uint randNonce = 0;
    // boletos de la loteria generadors
    uint [] boletosComprados;
    // compra de boletas de aleatorio
    function compraBoleto(uint _numBoletos) public {
        // precio total de los boletos a comprar
        uint precioTotal = _numBoletos*precioBoleto;
        // verificacion de los tokens del usuario 
        require(precioTotal <= balanceTokens(msg.sender),
                "No tienes tokens suficientes");

        // transferencia de tokens del usuario al smart contract
        _transfer(msg.sender, address(this), precioTotal);

        for(uint i = 0; i < _numBoletos; i++){
            uint random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce)))% 10000;
            randNonce++;
            // Almacenamiento de los datos del boletos enlazados al usuario
            idPersona_boletos[msg.sender].push(random);
            // almacenamiento de los datos de los boletos 
            boletosComprados.push(random);
            // Asignacion del ADN del boleto para la generacion de un ganador
            ADNBoletos[random] = msg.sender;
            // Creacion de un nuevo NFT para el numero de boleto 
            boletosNFTs(usuario_contracto[msg.sender]).mintBoleto(msg.sender, random);

        }

    }


    // visualizacion de los boletos del usuario 
    function tusBoletos(address _propietario) public view returns (uint [] memory) {
        return idPersona_boletos[_propietario];
    }

    // generar ganador del boleto
    function generarGanador() public onlyOwner {
        // Declaracion de la longitud
        uint longitud = boletosComprados.length;
        // verificacion de la compra de al menos de 1 boleto
        require(longitud > 0, "Boletos comprados");
        // Eleccion de aleatorio de un numero entre: 0 [long]
        uint random = uint(uint(keccak256(abi.encodePacked(block.timestamp))) % longitud);
        // seleccion del numero aleatorio
        uint eleccion = boletosComprados[random];
        // direccion del ganador de la boleta
        ganador = ADNBoletos[eleccion];

        //envio del 95% del premio de la loteria al ganador
        payable(ganador).transfer(address(this).balance * 95 / 100);
        // envio del 5% del premio de la loteria al Owner 
        payable(owner()).transfer(address(this).balance * 5 / 100);
    }

}

contract mainERC721 is ERC721 {

    address public direccionLoteria;
    constructor() ERC721("Loteria", "STE"){
        direccionLoteria = msg.sender;
    }

    // creacion de NFTs
    function safeMint(address _propietario, uint _boleto) public {
        require(msg.sender == loteria(direccionLoteria).usersInfo(_propietario),
                    "No tienes permiso para ejecutar esta function");
        _safeMint(_propietario, _boleto);
    }


}

contract boletosNFTs {
    // datos relevantes 
    struct Owner {
        address direccionPropietario;
        address contratoPadre;
        address contratoNFT;
        address contratoUsuario;
    }

    Owner public propietario;
    //conructor de smart contract (hijo)
    constructor(address _propietario, address _contratoPadre, address _contratoNFT) {
        propietario = Owner(_propietario,
                             _contratoPadre,
                             _contratoNFT,
                              address(this));
    }

    // conversion de los numeros boletos de loteria
    function mintBoleto(address _propietario, uint _boleto) public {
        require(msg.sender == propietario.contratoPadre, 
                    "No tienes permiso para ejecutar esta funcion");
        mainERC721(propietario.contratoNFT).safeMint(_propietario, _boleto);
    }
}
//><