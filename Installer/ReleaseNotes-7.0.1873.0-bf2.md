NanaZip 7.0.1873.0 — revisão 2 do instalador

Corrige a instalação com erro 0x80073D02 quando a versão anterior está aberta. O instalador tenta fechar normalmente os processos da versão personalizada, aguarda 5 segundos e termina os que continuam ativos. Repete a instalação uma vez se o Windows ainda indicar recursos em utilização.

Termine qualquer compressão ou extração antes de executar Install.cmd, pois as operações em curso podem ser interrompidas.

O MSIXBundle assinado e o certificado são os mesmos da release v7.0.1873.0-bf1; apenas o instalador e a documentação foram atualizados. A aplicação mantém a versão 7.0.1873.0 e as arquiteturas x64/ARM64.

Extraia todo o ZIP e execute Install.cmd. Verifique o ZIP através de SHA256SUMS.txt.
